// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "solmate/tokens/ERC20.sol";
import "solmate/tokens/ERC1155.sol";
import "solmate/utils/SafeTransferLib.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "solmate/auth/Owned.sol";

import "../src/interfaces/IVotingEscrow.sol";


contract CascadiaOptions is ERC1155, Owned {
    
    struct Option {
        uint96 cascadiaAmount;
        address exerciseAsset;
        uint96 exerciseAmount;
        uint40 exerciseTimestamp;
        uint40 expiryTimestamp;
        uint40 supply;
    }
    
    event OptionWritten(
        uint256 indexed id,
        uint96 cascadiaAmount,
        address exerciseAsset,
        uint96 exerciseAmount,
        uint40 exerciseTimestamp,
        uint40 expiryTimestamp,
        uint40 supply,
        address to
    );
    
    event OptionExercised(
        uint256 optionId,
        uint40 amount,
        address exercisedBy
    );
    
    event TreasuryUpdated(
        address newTreasury
    );
    
    event VeDiscountUpdated(
        uint256 newVeDiscount
    );
    
    event VotingEscrowUpdated(
        address newVotingEscrow
    );
    
    error WriterNotWhitelisted(address);
    error ValueMismatch(uint96, uint256);
    error NotOptionOwner(address, uint256);
    error ExerciseAssetNotReceived();
    error OptionExpired(uint256, uint40);
    error OptionNotExpired(uint256, uint40);
    error OptionExerciseTooEarly(uint256, uint40);
    error NotEnoughOptionsHeld(uint256, uint256);
    error OptionAlreadyRedeemed(uint256);
    
    IVotingEscrow votingEscrow;
    
    Option[] options;
    
    mapping(address => bool) whitelistedWriters;
    mapping(uint256 => bool) redeemedOptions;
    
    address public treasury;
    uint256 public veDiscount; // percentage
    
    constructor(address _treasury, uint256 _veDiscount, address _votingEscrow) 
        Owned(msg.sender) {
        treasury = _treasury;
        veDiscount = _veDiscount;
        votingEscrow = IVotingEscrow(_votingEscrow);
    }
    
    function updateTreasury(address newTreasury) public onlyOwner {
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }
    
    function updateVeDiscount(uint256 newVeDiscount) public onlyOwner {
        veDiscount = newVeDiscount;
        emit VeDiscountUpdated(newVeDiscount);
    }
    
    function updateVotingEscrow(address newVotingEscrow) public onlyOwner {
        votingEscrow = IVotingEscrow(newVotingEscrow);
        emit VotingEscrowUpdated(newVotingEscrow);
    }
    
    function write(
        uint96 cascadiaAmount,
        address exerciseAsset,
        uint96 exerciseAmount,
        uint40 exerciseTimestamp,
        uint40 expiryTimestamp,
        address to, 
        uint40 amount
    ) external payable onlyOwner {
        if (!whitelistedWriters[msg.sender]) {
            revert WriterNotWhitelisted(msg.sender);
        }
        if (uint256(cascadiaAmount) != msg.value) {
            revert ValueMismatch(cascadiaAmount, msg.value);
        }
        options.push(Option(
            cascadiaAmount,
            exerciseAsset,
            exerciseAmount,
            exerciseTimestamp,
            expiryTimestamp,
            amount
        ));
        _mint(to, options.length -1, amount, "");
        emit OptionWritten(
            options.length -1,
            cascadiaAmount,
            exerciseAsset,
            exerciseAmount,
            exerciseTimestamp,
            expiryTimestamp,
            amount,
            to
        );
    }
    
    function exercise(uint256 optionId, uint40 amount) external {
        Option storage option = options[optionId];
        if (option.expiryTimestamp <= block.timestamp) {
            revert OptionExpired(optionId, option.expiryTimestamp);
        }
        if (option.exerciseTimestamp > block.timestamp) {
            revert OptionExerciseTooEarly(optionId, option.exerciseTimestamp);
        }
        if (balanceOf[msg.sender][optionId] < amount) {
            revert NotEnoughOptionsHeld(amount, balanceOf[msg.sender][optionId]);
        }
        _burn(msg.sender, optionId, amount);
        // requring balance to be larger than amount above prevents underflow
        unchecked {
            option.supply = option.supply - amount;
        }
        SafeTransferLib.safeTransferFrom(
            ERC20(option.exerciseAsset), 
            msg.sender, 
            address(this), 
            option.exerciseAmount * amount
        );
        emit OptionExercised(
            optionId,
            amount,
            msg.sender
        );
        SafeTransferLib.safeTransferETH(msg.sender, option.cascadiaAmount * amount);
    }
    
    function exerciseToVe(uint256 optionId, uint40 amount) external {
        Option storage option = options[optionId];
        if (option.expiryTimestamp <= block.timestamp) {
            revert OptionExpired(optionId, option.expiryTimestamp);
        }
        if (option.exerciseTimestamp > block.timestamp) {
            revert OptionExerciseTooEarly(optionId, option.exerciseTimestamp);
        }
        if (balanceOf[msg.sender][optionId] < amount) {
            revert NotEnoughOptionsHeld(amount, balanceOf[msg.sender][optionId]);
        }
        _burn(msg.sender, optionId, amount);
        // requring balance to be larger than amount above prevents underflow
        unchecked {
            option.supply = option.supply - amount;
        }
        SafeTransferLib.safeTransferFrom(
            ERC20(option.exerciseAsset), 
            msg.sender, 
            address(this), 
            (option.exerciseAmount * 100 / veDiscount) * amount
        );
        emit OptionExercised(
            optionId,
            amount,
            msg.sender
        );
        votingEscrow.deposit_for{value: option.cascadiaAmount * amount}(msg.sender);
    }
    
    function redeem(uint256 optionId) external onlyOwner {
        Option memory option = options[optionId];
        if (option.expiryTimestamp > block.timestamp) {
            revert OptionNotExpired(optionId, option.expiryTimestamp);
        }
        if (redeemedOptions[optionId]) {
            revert OptionAlreadyRedeemed(optionId);
        }
        redeemedOptions[optionId] = true;
        SafeTransferLib.safeTransferETH(treasury, option.cascadiaAmount * option.supply);
    }
    
    function uri(uint256 optionId) override public view returns (string memory tokenUri) {
        string memory tokenUri = "placeholder";
    }
}
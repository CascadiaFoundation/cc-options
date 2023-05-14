// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "solmate/tokens/ERC20.sol";
import "solmate/tokens/ERC1155.sol";
import "solmate/utils/SafeTransferLib.sol";
import "solmate/utils/FixedPointMathLib.sol";

/*
- add admin address
- add update admin address
- add update treasury address
- add redeem CC function for expired options
- add advanced discount for veCC
*/

contract CascadiaOptions is ERC1155 {
    
    struct Option {
        uint96 cascadiaAmount;
        address exerciseAsset;
        uint96 exerciseAmount;
        uint40 exerciseTimestamp;
        uint40 expiryTimestamp;
    }
    
    event OptionWritten(
        uint256 indexed id,
        uint96 cascadiaAmount,
        address exerciseAsset,
        uint96 exerciseAmount,
        uint40 exerciseTimestamp,
        uint40 expiryTimestamp,
        address to
    );
    
    event OptionExercised(
        uint256 optionId,
        uint256 amount,
        address exercisedBy
    );
    
    error WriterNotWhitelisted(address);
    error ValueMismatch(uint96, uint256);
    error NotOptionOwner(address, uint256);
    error ExerciseAssetNotReceived();
    error OptionExpired(uint256, uint40);
    error OptionExerciseTooEarly(uint256, uint40);
    
    Option[] options;
    
    mapping(address => bool) whitelistedWriters;
    
    address public treasury;
    
    constructor(address _treasury) {
        treasury = _treasury;
    }
    
    function write(
        uint96 cascadiaAmount,
        address exerciseAsset,
        uint96 exerciseAmount,
        uint40 exerciseTimestamp,
        uint40 expiryTimestamp,
        address to
    ) external {
        if (!whitelistedWriters(msg.sender)) {
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
            expiryTimestamp
        ));
        _mint(options.length -1, to);
        emit OptionWritten(
            options.length -1,
            cascadiaAmount,
            exerciseAsset,
            exerciseAmount,
            exerciseTimestamp,
            expiryTimestamp,
            to
        )
    }
    
    function exercise(uint256 optionId, uint256 amount) external {
        Option option = Options[optionId];
        if (option.expiryTimestamp <= block.timestamp) {
            revert OptionExpired(optionId, option.expiryTimestamp);
        }
        if (optionRecord.exerciseTimestamp > block.timestamp) {
            revert OptionExerciseTooEarly(optionId, option.exerciseTimestamp);
        }
        if (balanceOf[msg.sender][optionId] < amount) {
            revert NotEnoughOptionsHeld(amount, balanceOf[msg.sender][optionId]);
        }
        _burn(msg.sender, optionId, amount);
        SafeTransferLib.safeTransferFrom(
            ERC20(option.exerciseAsset), 
            msg.sender, 
            address(this), 
            option.exerciseAmount
        );
        emit OptionExercised(
            optionId,
            amount,
            msg.sender
        );
        safeTransferETH(msg.sender, option.cascadiaAmount);
    }
    
    function uri(uint256 optionId) override public view returns (string memory tokenUri) {
        string tokenUri = "placeholder";
    }
}
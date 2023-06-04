// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "./MockERC20.sol";
import "./MockSmartWalletChecker.sol";

import "../src/CascadiaOptions.sol";

import "../lib/utils/VyperDeployer.sol";
import "../src/interfaces/IVotingEscrow.sol";

contract CascadiaOptionsTest is Test {

    MockERC20 public mockToken;
    CascadiaOptions public cascadiaOptions;
    address user1 = makeAddr("user1");
    address admin = makeAddr("admin");
    address treasury = makeAddr("treasury");
    IVotingEscrow votingEscrow;
    VyperDeployer vyperDeployer = new VyperDeployer();

    function setUp() public {
        vm.deal(admin, 100 ether);
        mockToken = new MockERC20("Mock Token", "MT", 18);
        votingEscrow = IVotingEscrow(vyperDeployer.deployContract(
            "VotingEscrow", 
            abi.encode("VotingEscrow", "veCC", "1", address(admin)))
        );
        vm.prank(admin);
        cascadiaOptions = new CascadiaOptions(
            address(treasury), 
            10,
            address(votingEscrow)
        );
    }
    
    ///////////////////////////////////////////////////////////////////////////
    // TEST MAIN OPTION LOGIC                                                //
    ///////////////////////////////////////////////////////////////////////////
    
    function testWrite() public {
        vm.startPrank(admin);
        cascadiaOptions.whitelistWriter(address(admin), true);
        cascadiaOptions.write{value: 1 ether * 3}(
            1 ether, // cascadiaAmount
            address(mockToken), // exerciseAsset
            500, // exerciseAmount
            uint40(block.timestamp), // exerciseTimestamp
            uint40(block.timestamp + 3600), // expiryTimestamp
            address(user1), // to 
            3 // amount
        );
        vm.stopPrank();
        assertEq(cascadiaOptions.balanceOf(address(user1), 0), 3);
    }
    
    function testExercise() public {
        testWrite();
        vm.startPrank(user1);
        mockToken.mint(user1, 10000 ether);
        mockToken.approve(address(cascadiaOptions), 10000 ether);
        cascadiaOptions.exercise(0, 1);
        vm.stopPrank();
        assertEq(mockToken.balanceOf(cascadiaOptions.treasury()), 500);
        assertEq(address(user1).balance, 1 ether);
    }
    
    function testExerciseToVe() public {
        testWrite();
        MockSmartWalletChecker walletChecker = new MockSmartWalletChecker();
        walletChecker.add(address(cascadiaOptions), true);
        walletChecker.add(address(user1), true);
        vm.startPrank(admin);
        votingEscrow.commit_smart_wallet_checker(address(walletChecker));
        votingEscrow.apply_smart_wallet_checker();
        vm.stopPrank();
        vm.deal(user1, 0.5 ether);
        vm.startPrank(user1);
        mockToken.mint(user1, 10000 ether);
        mockToken.approve(address(cascadiaOptions), 10000 ether);
        votingEscrow.create_cooldown_lock{value: 0.5 ether}(365 * 86400);
        cascadiaOptions.exerciseToVe(0, 1);
        vm.stopPrank();
    }
    
    ///////////////////////////////////////////////////////////////////////////
    // TEST CONTRACT ADMIN FUNCTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////
    
    function testRedeem() public {
        testWrite();
        // reverts redeem before expiry
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(
            CascadiaOptions.OptionNotExpired.selector,
            0,
            3601
        ));
        cascadiaOptions.redeem(0);
        // reverts redeem from non-admin
        vm.warp(3601);
        vm.prank(user1);
        vm.expectRevert();
        cascadiaOptions.redeem(0);
        // allows admin to redeem
        vm.startPrank(admin);
        cascadiaOptions.redeem(0);
        // reverts redeem when already redeemed
        vm.expectRevert(abi.encodeWithSelector(
            CascadiaOptions.OptionAlreadyRedeemed.selector,
            0
        ));
        cascadiaOptions.redeem(0);
        vm.stopPrank();
        assertEq(address(cascadiaOptions).balance, 0 ether);
        assertEq(address(treasury).balance, 3 ether);
        // add tests for redeeming after options have been exercised partially      
    }
    
    function testUpdateTreasury() public {
        assertEq(cascadiaOptions.treasury(), address(treasury));
        address newTreasury = makeAddr("newTreasury");
        vm.prank(user1);
        vm.expectRevert();
        cascadiaOptions.updateTreasury(newTreasury);
        vm.prank(admin);
        cascadiaOptions.updateTreasury(newTreasury);
        assertEq(cascadiaOptions.treasury(), newTreasury); 
    }
    
    function testUpdateVeDiscount() public {
        uint256 newVeDiscount = 5;
        vm.prank(user1);
        vm.expectRevert();
        cascadiaOptions.updateVeDiscount(newVeDiscount);
        vm.prank(admin);
        cascadiaOptions.updateVeDiscount(newVeDiscount);
        assertEq(cascadiaOptions.veDiscount(), newVeDiscount); 
    }
    
    function testUpdateVotingEscrow() public {
        assertEq(address(cascadiaOptions.votingEscrow()), address(votingEscrow));
        IVotingEscrow newVotingEscrow = IVotingEscrow(vyperDeployer.deployContract(
            "VotingEscrow", 
            abi.encode("VotingEscrow", "veCC2", "1", address(admin)))
        );
        vm.prank(user1);
        vm.expectRevert();
        cascadiaOptions.updateVotingEscrow(address(newVotingEscrow));
        vm.prank(admin);
        cascadiaOptions.updateVotingEscrow(address(newVotingEscrow));
        assertEq(address(cascadiaOptions.votingEscrow()), address(newVotingEscrow));
    }
    
    function testWhitelistWriter() public {
        address newWriter = makeAddr("newWriter");
        assertFalse(cascadiaOptions.whitelistedWriters(newWriter));
        vm.prank(user1);
        vm.expectRevert();
        cascadiaOptions.whitelistWriter(newWriter, true);
        vm.startPrank(admin);
        cascadiaOptions.whitelistWriter(newWriter, true);
        assertTrue(cascadiaOptions.whitelistedWriters(newWriter));
        cascadiaOptions.whitelistWriter(newWriter, false);
        vm.stopPrank();
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "./MockERC20.sol";

import "../src/CascadiaOptions.sol";

import "../lib/utils/VyperDeployer.sol";
import "../src/interfaces/IVotingEscrow.sol";

contract CascadiaOptionsTest is Test {

    MockERC20 public mockToken;
    CascadiaOptions public cascadiaOptions;
    address user1 = makeAddr("user1");
    address admin = makeAddr("admin");
    address treasury = makeAddr('treasury');
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
        cascadiaOptions.write{value: 1 ether}(
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
        vm.deal(user1, 0.5 ether);
        vm.startPrank(user1);
        mockToken.mint(user1, 10000 ether);
        mockToken.approve(address(cascadiaOptions), 10000 ether);
        // create smart_wallet_checker contract for VotingEscrow
        // whitelist CascadiaOptions contract in VotingEscrow
        // votingEscrow.create_cooldown_lock{value: 0.5 ether}(4 * 365 * 86400);
        // cascadiaOptions.exerciseToVe(0, 1);
        vm.stopPrank();
    }
    
    ///////////////////////////////////////////////////////////////////////////
    // TEST CONTRACT ADMIN FUNCTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////
    function testRedeem() public {
        
    }
    
    function testUpdateTreasury() public {
        
    }
    
    function testUpdateVeDiscount() public {
        
    }
    
    function testUpdateVotingEscrow() public {
        
    }
}
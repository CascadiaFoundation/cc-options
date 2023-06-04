// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0;

interface IVotingEscrow {
    function deposit_for(address) external payable;
    function create_cooldown_lock(uint256) external payable;
    function commit_smart_wallet_checker(address) external;
    function apply_smart_wallet_checker() external;
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

contract MockSmartWalletChecker {
    
    mapping(address => bool) public whitelisted;
    
    function add(address addr, bool permission) public {
        whitelisted[addr] = permission;
    }

    function check(address addr) public returns(bool) {
        return whitelisted[addr];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract Vault {
    // we need to pass the token address to the constructor
    // create a deposit function that mint tokens to the user to the amount of ETH the user
    // create a redeem function that burns tokens from the user and sends the user ETH
    // create a way to add rewards to the vault
    address private immutable i_rebaseToken;

    constructor (address _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    function getRebaseTokenAddress()external view returns(address) {
       return i_rebaseToken;
    }
}
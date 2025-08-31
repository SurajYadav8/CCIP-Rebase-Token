// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";



contract TokenAndPoolDeployer is Script{

    function 
}

contract VaultDeployer is Script {
    function run(address _rebaseToken) public returns(Vault vault) {
        vm.startBroadcast();
        Vault vault = new Vault(IRebaseToken(_rebaseToken));
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
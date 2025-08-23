// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {Pool} from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/ccip/interfaces/IERC20.sol";

contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address[] memory _allowlist, address _rnmProxy, address _router)
        TokenPool( _token, _allowlist, _rnmProxy, _router)
    {}
}

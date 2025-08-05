// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";


/*
* @title RebaseToken
* @author Suraj Yadav
* @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
* @notice The interest rate in the smart contract can only decrease
* @notice Each user will have their own interest rate that is the global interset rate at the time of depositing.
*/
contract RebaseToken is ERC20 {

    error RebaseToekn_InterestRateCanOnlyDecrease(uint oldInterestRate, uint256 newInterestRate);
    
    uint256 private s_interestRate = 5e10;

    event InterestRate(uint256 newInterestRate);

    constructor() ERC20 ("Rebase Token", "RBT") {

    }

    /*
    * @notice Set the interest rate in the contract
    * @param _newInterestRate The new interest rate to set
    * @dev The interest rate can only decrease
    */

    function setInterestRate(uint256 _newInterestRate) external {

        if(_newInterestRate < s_interestRate) {
            revert RebaseToekn_InterestRateCanOnlyDecrease (s_interestRate,  _newInterestRate);
        }

        s_interestRate = _newInterestRate;
        emit InterestRate(_newInterestRate);
    }
     
}
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
    
    uint256 private constant PRECISION_FACTOR = 1e18; 
    uint256 private s_interestRate = 5e10;
    mapping (address => uint256) private s_userInterestRate;
    mapping (address => uint256) private s_userLastUpdatedTimestamp;

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

    /*
    * @notice Mint the user tokens when they deposit into the vault
    * @param _to The user to mint the tokens to 
    * @param _amount The amount of tokens to mint
    */

    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);  // AccruedInterest mtlb purana hisab kitab jo abhi diya nhi hai 
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount); // inherited from ERC20 contract of openzeppelin
    }
    /*
    * @notice Burn the user tokens when they withdrawl from the vault
    * @param _from The user to burn the tokens from
    * @param _amount The amount of tokens to burn
    */

    function burn(address _from, uint256 _amount) external {
        if (_amount == type(uint256).max){
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);

    }

    /*
    * calculate the balance for the user including the interest that has accumulated since the balance last updated
    * (principle balance) + some interest that has accrued
    * @param _user The user to calculate the balance for
    * @return The balance of the user including the interest that has accumulated since the last updated 
    */ 

    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user (the number of tokens that have actually been minted to the user)
        // mulitply the principle balance by the interest that has accumulated in the time since the balance is last updated
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR; // here super keyword is used to connect that balanceof function in ERC20 openzeppelin 
    }


    function transfer(address _recipient, uint256 _amount) public override returns(bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if(_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if(balanceOf(_recipient) == 0 ) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);

    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }

        if(balanceOf (_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }
    /*
    * @notice Calculate the interest that has accumulated since the last update
    * @param _user The user to calculate the interst accumulated for
    * @return The interest thjat has accumulated since the last update
    */ 

   function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns(uint256 linearInterest) {
    // we need to calculate the interest that has accumulated since the last update
    // this is going to be linear growth with time
    // 1. Calculating the time since the last update
    // 2. Calculate the amount of linear growth
    // principal amount (1 + (user interest rate * time elapsed))
    // deposit: 10 tokens
    // interest rate 0.5 tokens per second
    // time elapsed is 2 seconds
    // 10 + (10*0.5*2)
    uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
    linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
   }

   /*
   * @notice Mint the accured interest to user since the last time they interacted with the protocol (e.g. burn, mint, transfer)
   * @param _user The user to mint the accured interest to 
   */ 
    function _mintAccruedInterest(address _user) internal {
        // find the current balance of rebase tokens that have been minted to the user -> principal amount
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate the numberof tokens that need to be minted to the user -> (2) - (1)
        uint256 balanceIncreased = currentBalance - previousPrincipleBalance;
        // set the users last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        // call _mint to mint the tokens to the user
        _mint(_user, balanceIncreased);

    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
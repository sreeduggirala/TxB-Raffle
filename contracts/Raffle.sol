//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// Custom Errors
error Raffle__SendMoreToEnterRaffle();
error Raffle__RaffleClosed();
error Raffle__RaffleOpen();
error Raffle__RaffleNotFilled();
error Raffle__OnlyOwnerCanAccess();

contract Raffle {
    
    enum RaffleState {
        Open,
        Closed,
        Calculating
    }
    
    RaffleState public raffleState; //type RaffleState - variable stores raffle's state

    address payable immutable owner;
    uint public raffleID;
    uint public immutable entranceFee;
    uint public immutable maxEntries;
    uint public startTime;
    uint public raffleDuration;
    
    address payable[] public players;

    event RaffleEnter(address indexed player);
    event RaffleWinner(address indexed winner);

    constructor(uint _raffleDuration, uint _entranceFee, uint _maxEntries) {
        owner = payable(msg.sender);
        raffleID++;
        entranceFee = _entranceFee;
        maxEntries = _maxEntries;
        startTime = block.timestamp;
        raffleDuration = _raffleDuration;
    }

    //owner sends NFT to contract after or during creation of raffle

    function enterRaffle(uint _numTickets) external payable { //depositAsset has to receive NFT; users cannot enter empty raffle
        if(msg.value < entranceFee * _numTickets) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if(raffleState != RaffleState.Open) {
            revert Raffle__RaffleClosed();
        }

        for (uint256 i = 0; i < _numTickets; i++) {
            players.push(payable(msg.sender));
        }
        emit RaffleEnter(msg.sender);
    }

    modifier onlyOwner {
        if (msg.sender != owner) {
            revert Raffle__OnlyOwnerCanAccess();
        }
        _;
    }

    function runRaffle() public {} //VRF picks winner if minimum entries are met and time ends

    function claimPrize() external {} //winner claims prize after raffle runs

    function refundPlayers() external {} //if raffle fails, winners can receive refunds

    function refundOwner() onlyOwner external {} //if raffle fails, owner can withdraw asset
}
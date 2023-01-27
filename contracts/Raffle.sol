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

    bytes10 public immutable raffleName;
    uint public startTime;
    uint public raffleDuration;
    address payable owner;
    uint public immutable entranceFee;
    uint public immutable minimumTickets;
    address payable[] public players;

    event RaffleEnter(address indexed player);

    constructor(bytes8 _raffleName, uint _raffleDuration, uint _entranceFee, uint _minimumTickets) {
        raffleName = _raffleName;
        startTime = block.timestamp;
        raffleDuration = _raffleDuration;
        owner = payable(msg.sender);
        entranceFee = _entranceFee;
        minimumTickets = _minimumTickets;

    }

    function depositAsset() public payable onlyOwner { //owner sends NFT to contract

    }

    function enterRaffle() external payable { //depositAsset has to receive NFT; users cannot enter empty raffle
        if(msg.value < entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if(raffleState != RaffleState.Open) {
            revert Raffle__RaffleClosed();
        }

        players.push(payable(msg.sender));
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

    function refundPlayers() external {} //if raffle fails, winners  can receive refunds

    function refundOwner() onlyOwner external {} //if raffle fails, owner can withdraw asset
}
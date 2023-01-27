//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

error Raffle__SendMoreToEnterRaffle(); //custom errors - require is expensive
error Raffle__RaffleClosed();
error Raffle__RaffleOpen();
error Raffle__RaffleNotFilled();

contract Raffle {
    
    enum RaffleState {
        Open,
        Closed,
        Calculating
    }
    RaffleState public raffleState; //type RaffleState - variable stores raffle's state

    bytes10 raffleName;
    uint startTime;
    address payable owner;
    uint public immutable entranceFee;
    uint public minimumTickets;
    address payable[] public players;

    event RaffleEnter(address indexed player);

    constructor(bytes8 _raffleName, uint _entranceFee, uint _minimumTickets) {
        raffleName = _raffleName;
        startTime = block.timestamp;
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
        require(msg.sender == owner, "Only available to lottery owner");
        _;
    }

    function runRaffle() public {} //VRF picks winner if minimum entries are met and time ends

    function claimPrize() external {} //winner claims prize if raffle successfully completes

    function refundPlayers() external {} //if raffle fails, winners receive refunds

    function refundOwner() onlyOwner external {} //if raffle fails, owner withdraws asset
}
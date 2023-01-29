//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// Custom Errors
error Raffle__SendMoreToEnterRaffle();
error Raffle__CannotBuy0Slots();
error Raffle__ContractNotHoldingNFT();
error Raffle__RaffleOpen();
error Raffle__RaffleClosed();
error Raffle__RaffleFilled();
error Raffle__RaffleNotFilled();
error Raffle__WinnerAlreadySelected();
error Raffle__OnlyOwnerCanAccess();

contract Raffle {
    enum RaffleState {
        Open,
        Closed,
        Calculating
    }

    RaffleState public raffleState;

    // Raffle Content
    address payable immutable owner;
    uint public immutable ticketFee;
    uint public immutable maxTickets;
    uint public startTime;
    uint public endTime;
    address nftContract;
    uint public nftID;
    bool holdingNFT;

    // Player Content
    address payable[] public players;
    mapping(address => uint) playerTickets;

    // Events
    event RaffleEntered(address indexed player, uint numClaimed);
    event RaffleRefunded(address indexed player, uint numRefunded);
    event RaffleWinner(address indexed winner);

    constructor(uint _ticketFee, uint _maxTickets, uint _startTime, uint _endTime) {
        owner = payable(msg.sender);
        ticketFee = _ticketFee;
        maxTickets = _maxTickets;
        startTime = _startTime;
        endTime = _endTime;
    }

    //owner needs to send NFT to contract after creation of raffle

    function enterRaffle(uint _numTickets) payable external { //contract has to receive/own NFT; users cannot enter empty raffle
        if( _numTickets <= 0) {
            revert Raffle__CannotBuy0Slots();
        }

        if(holdingNFT == false) {
            revert Raffle__ContractNotHoldingNFT();
        }
        
        if (msg.value < ticketFee * _numTickets) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if (raffleState != RaffleState.Open) {
            revert Raffle__RaffleClosed();
        }

        for (uint i = 0; i < _numTickets; i++) {
            players.push(payable(msg.sender));
        }

        emit RaffleEntered(msg.sender, _numTickets);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Raffle__OnlyOwnerCanAccess();
        }
        _;
    }

    modifier nftHeld() {
        if(holdingNFT == false) {
            revert Raffle__ContractNotHoldingNFT();
        }
        _;
    }

    function runRaffle() public {} //VRF selects winner when time ends

    function disbursement() external {} //winner and owner receive respective assets

    function refundPlayer() external {} //players can refund tickets before winner selection

    function deleteRaffle() external onlyOwner {} //only owner can delete raffle before winner selection
}

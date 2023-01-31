//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// Custom Errors
error Raffle__SendMoreToEnterRaffle();
error Raffle__CannotBuy0Slots();
error Raffle__ContractNotHoldingNFT();
error Raffle__RaffleOpen();
error Raffle__RaffleClosed();
error Raffle__InsufficientTicketsLeft();
error Raffle__RaffleFull();
error Raffle__RaffleNotFull();
error Raffle__VRFNumberStillLoading();
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
    uint256 public immutable ticketFee;
    uint256 public immutable maxTickets;
    uint256 public startTime;
    uint256 public endTime;
    address nftContract;
    uint256 public nftID;
    bool holdingNFT;

    //Chainlink Content
    uint256 vrfNumber; //resulting number from VRF
    bool public vrfRequested;

    // Player Content
    address payable[] public players;
    mapping(address => uint256) playerTickets;

    // Events
    event RaffleEntered(address indexed player, uint256 numPurchased);
    event RaffleRefunded(address indexed player, uint256 numRefunded);
    event RaffleWinner(address indexed winner);

    constructor(uint256 _ticketFee, uint256 _maxTickets, uint256 _startTime, uint256 _endTime) {
        owner = payable(msg.sender);
        ticketFee = _ticketFee;
        maxTickets = _maxTickets;
        startTime = _startTime;
        endTime = _endTime;
    }

    //owner needs to send NFT to contract after creation of raffle

    function enterRaffle(uint256 _numTickets) payable external nftHeld { //contract has to receive/own NFT; users cannot enter empty raffle
        if( _numTickets <= 0) {
            revert Raffle__CannotBuy0Slots();
        }
        
        if (msg.value < ticketFee * _numTickets) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if(maxTickets - players.length < _numTickets) {
            revert Raffle__InsufficientTicketsLeft();
        }

        if(players.length == _numTickets) {
            revert Raffle__RaffleFull();
        }

        if (raffleState != RaffleState.Open) {
            revert Raffle__RaffleClosed();
        }

        for (uint256 i = 0; i < _numTickets; i++) {
            players.push(payable(msg.sender));
        }

        playerTickets[msg.sender] += _numTickets;

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

    function disbursement() external nftHeld {
        if(vrfNumber == 0) {
            revert Raffle__VRFNumberStillLoading();
        }

        payable(owner).transfer((address(this).balance * 98)/100);
        address winner = players[vrfNumber % players.length];
        //transfer NFT to winner
        holdingNFT = false;
        emit RaffleWinner(winner);
    }

    function deleteRaffle() external onlyOwner nftHeld {
        //cannot delete raffle after winner has been selected
        //transfer NFT to original owner

        holdingNFT = false;

        for(uint256 i = (players.length) - 1; i >= 0; i--) {
            payable(players[i]).transfer(ticketFee);
            players.pop();
        }
    } //only owner can delete raffle before winner selection; NFT gets transferred to owner and players receive refunds
}

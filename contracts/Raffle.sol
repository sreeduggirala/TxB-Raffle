//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";

// Custom Errors
error NotOwner();
error InvalidAddress();
error Raffle__SendMoreToEnterRaffle();
error Raffle__CannotBuy0Slots();
error Raffle__RaffleFull();
error Raffle__RaffleOngoing();
error Raffle__ContractNotHoldingNFT();
error Raffle__InsufficientTicketsLeft();
error Raffle__InsufficientTicketsBought();
error Raffle__RandomNumberStillLoading();
error Raffle__WinnerAlreadySelected();
error Raffle__OnlyNFTOwnerCanAccess();

contract Raffle {
    //Owner
    address payable owner; 

    // Raffle Content
    address payable immutable nftOwner;
    uint256 public immutable ticketFee;
    uint256 public immutable maxTickets;
    uint256 public startTime;
    uint256 public endTime;
    bool holdingNFT;

    //Chainlink Content
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomNumber;
    bool public randomNumberRequested;

    // Player Content
    address payable[] public players;
    mapping(address => uint256) public playerTickets;

    // Events
    event RaffleEntered(address indexed player, uint256 numPurchased);
    event RaffleRefunded(address indexed player, uint256 numRefunded);
    event RaffleWinner(address indexed winner);

    constructor(uint256 _ticketFee, uint256 _maxTickets, uint256 _startTime, uint256 _endTime) {
        nftOwner = payable(msg.sender);
        ticketFee = _ticketFee;
        maxTickets = _maxTickets;
        startTime = _startTime;
        endTime = _endTime;
    }

    modifier onlynftOwner() {
        if(msg.sender != nftOwner) {
            revert Raffle__OnlyNFTOwnerCanAccess();
        }
        _;
    }

    modifier nftHeld() {
        if(holdingNFT != true) {
            revert Raffle__ContractNotHoldingNFT();
        }
        _;
    }

    modifier vrfCalled() {
        if(randomNumberRequested == true) {
            revert Raffle__WinnerAlreadySelected();
            _;
        }
    }

    modifier onlyOwner() {
        if(msg.sender == owner) {
            revert NotOwner();
        }
        _;
    }

    function enterRaffle(uint256 _numTickets) payable external nftHeld { //contract has to receive/own NFT; vrfCalled mod
        if(_numTickets <= 0) {
            revert Raffle__CannotBuy0Slots();
        }
        
        if(msg.value < ticketFee * _numTickets) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if(maxTickets - players.length < _numTickets) {
            revert Raffle__InsufficientTicketsLeft();
        }

        if(players.length == maxTickets) {
            revert Raffle__RaffleFull();
        }

        for(uint256 i = 0; i < _numTickets; i++) {
            players.push(payable(msg.sender));
        }

        playerTickets[msg.sender] += _numTickets;

        emit RaffleEntered(msg.sender, _numTickets);
    }
    
    function exitRaffle(uint256 _numTickets) external nftHeld { //vrfCalled mod
        if(playerTickets[msg.sender] < _numTickets) {
            revert Raffle__InsufficientTicketsBought();
        }

        uint256 i;
        while(i < players.length && _numTickets > 0) {
            if(players[i] != msg.sender) {
                i++;
            }

            else {
                players[i] = players[players.length - 1];
                players.pop();
                payable(msg.sender).transfer(ticketFee);
            }
        }

        emit RaffleRefunded(msg.sender, _numTickets);
    }

    function receiveRandomWinner() external {}

    function fulfillRandomness() external {}

    function disbursement() external nftHeld {
        if(randomNumber == 0) {
            revert Raffle__RandomNumberStillLoading();
        }

        payable(nftOwner).transfer((address(this).balance * 975)/1000);
        address winner = players[randomNumber % players.length];
        //transfer NFT to winner
        holdingNFT = false;
        emit RaffleWinner(winner);
    }

    function deleteRaffle() external onlynftOwner nftHeld { //vrfCalled mod
        //transfer NFT to original nftOwner

        holdingNFT = false;

        for(uint256 i = players.length - 1; i >= 0; i--) {
            payable(players[i]).transfer(ticketFee);
            players.pop();
        }
    }

    //receiving nft function w/ vrfCalled mod

    function withdrawCommission() external onlyOwner {
        payable(owner).transfer((address(this).balance * 25)/1000);
    }

    function reappointOwner(address payable _newOwner) external onlyOwner {
        if(_newOwner == address(0)) {
            revert InvalidAddress();
        }

        owner = _newOwner;
    }
}

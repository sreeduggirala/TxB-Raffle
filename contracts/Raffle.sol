//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";

// Custom Errors
error NotOwner();
error InvalidAddress();
error InsufficientAmount();
error InvalidSlotAmount();
error RaffleFull();
error RaffleOngoing();
error ContractNotHoldingNFT();
error ContractHoldingNFT();
error InsufficientTicketsLeft();
error InsufficientTicketsBought();
error RandomNumberStillLoading();
error WinnerAlreadyChosen();
error OnlyNFTOwnerCanAccess(); 
error NoRaffleForThisNFT();
error NoRaffleForThisID();

// You do not need to inherit from IERC721. Also, 
// contract should not be abstract, but that can be fixed once you implement 
// the Chainlink logic.
abstract contract Raffle is VRFV2WrapperConsumerBase, Ownable {
    //Contract Owner
    // address payable public owner; 

    //Raffle Content
    address payable immutable nftOwner;
    uint256 public immutable ticketFee;
    uint256 public immutable maxTickets;
    uint256 public startTime;
    uint256 public endTime;
    address public immutable nftContract;
    uint256 public immutable nftID;

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

    constructor(uint256 _ticketFee, uint256 _maxTickets, uint256 _startTime, uint256 _endTime, address _nftContract, uint256 _nftID) {
        // owner = payable(address(0x8B603f2890694cF31689dFDA28Ff5e79917243e9)); taken care of by Ownable
        nftOwner = payable(msg.sender);
        ticketFee = _ticketFee;
        maxTickets = _maxTickets;
        startTime = _startTime;
        endTime = _endTime;
        nftContract = _nftContract;
        nftID = _nftID;
    }

    // Only the owner of the raffle can access this function.
    modifier onlynftOwner() {
        if(msg.sender != nftOwner) {
            revert OnlyNFTOwnerCanAccess();
        }
        _;
    }

    // Function only works if contract is holding the NFT.
    modifier nftHeld() {
        require(IERC721(nftContract).ownerOf(nftID) == address(this), "Contract is not holding the raffle NFT");
        _;
    }

    // Function only works if random number was not chosen yet.
    modifier vrfCalled() {
        if(randomNumberRequested == true) {
            revert WinnerAlreadyChosen();
            _;
        }
    }

    // Enter the NFT raffle
    function enterRaffle(uint256 _numTickets) payable external nftHeld { //vrfCalled mod
        if(_numTickets <= 0) {
            revert InvalidSlotAmount();
        }
        
        if(msg.value < ticketFee * _numTickets) {
            revert InsufficientAmount();
        }

        // Consider not setting a cap on the amount of tickets to be sold. If there is a particularly hot raffle, 
        // a LOT of people are going to be reverted at this conditional.
        if(maxTickets - players.length < _numTickets) {
            revert InsufficientTicketsLeft();
        }

        // You can delete this. It functions the same as the conditional above. Also, if I bought the last ticket, this would still revert.
        if(players.length == maxTickets) {
            revert RaffleFull();
        }

        for(uint256 i = 0; i < _numTickets; i++) {
            players.push(payable(msg.sender));
        }

        playerTickets[msg.sender] += _numTickets;

        emit RaffleEntered(msg.sender, _numTickets);
    }
    
    // We went over this. here is a potential fix:
    function exitRaffle(uint256 _numTickets) external nftHeld { //vrfCalled mod
        if(playerTickets[msg.sender] < _numTickets) {
            revert InsufficientTicketsBought();
        }

        uint256 nt = _numTickets;
        uint256 i = 0;
        while(i < players.length && nt > 0) {
            if(players[i] != msg.sender) {
                i++;
            }

            else {
                players[i] = players[players.length - 1];
                players.pop();
                payable(msg.sender).transfer(ticketFee);
                nt--;
            }
        }

        emit RaffleRefunded(msg.sender, _numTickets);
    }

    function receiveRandomWinner() external {} //Chainlink

    function fulfillRandomness() external {} //Chainlink

    function disbursement() external nftHeld { ///automatically occurrs when time runs out
        // Theoretically, the randomNumber can be 0, and if it is, the person who bought the first ticket will be pretty mad.
      // maybe initialize randomNumber to uint256(-1).
        if(randomNumber == 0) {
            revert RandomNumberStillLoading();
        }

        payable(nftOwner).transfer((address(this).balance * 975)/1000);
        address payable winner = payable(players[randomNumber % players.length]);
        IERC721(nftContract).safeTransferFrom(address(this), winner, nftID);
        emit RaffleWinner(winner);
    }

    function deleteRaffle() external onlynftOwner nftHeld { //vrfCalled mod
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, nftID);

        for(uint256 i = players.length - 1; i >= 0; i--) {
            payable(players[i]).transfer(ticketFee);
            players.pop();
        }
    }

    function ownerCommission() external onlyOwner { 
        if(IERC721(nftContract).ownerOf(nftID) == address(this)) {
            revert ContractNotHoldingNFT();
        }
        payable(owner()).transfer((address(this).balance));
    }

    // This is already implemented with TransferOwnership in Ownable
    // function reappointOwner(address payable _newOwner) external onlyOwner {
    //    if(_newOwner == address(0)) {
    //        revert InvalidAddress();
    //    }

    //   owner = _newOwner;
    //}
}

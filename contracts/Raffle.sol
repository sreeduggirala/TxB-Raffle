//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

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

// contract shouldn't be abstract once Chainlink is implemented
abstract contract Raffle is Ownable, VRFConsumerBaseV2 {
    
    // Raffle Content
    address payable public nftOwner;
    uint256 public ticketFee;
    uint256 public minTickets;
    uint256 public startTime;
    uint256 public endTime;
    address public nftContract;
    uint256 public nftID;

    // Chainlink Content
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomNumber = type(uint256).max;
    bool public randomNumberRequested;

    // Player Content
    address payable[] public players;
    mapping(address => uint256) public playerTickets;

    // Events
    event RaffleEntered(address indexed player, uint256 numPurchased);
    event RaffleRefunded(address indexed player, uint256 numRefunded);
    event RaffleWinner(address indexed winner);

    constructor(uint256 _ticketFee, uint256 _minTickets, uint256 _startTime, 
    uint256 _endTime, address _nftContract, uint256 _nftID) Ownable() {
        _transferOwnership(_msgSender());
        nftOwner = payable(msg.sender);
        ticketFee = _ticketFee;
        minTickets = _minTickets;
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
        if(IERC721(nftContract).ownerOf(nftID) != address(this)) {
            revert ContractNotHoldingNFT();
        }
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

        for(uint256 i = 0; i < _numTickets; i++) {
            players.push(payable(msg.sender));
        }

        playerTickets[msg.sender] += _numTickets;

        emit RaffleEntered(msg.sender, _numTickets);
    }
    
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
}

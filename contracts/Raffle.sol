//SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

// Custom Errors
error InsufficientAmount();
error InvalidTicketAmount();
error RaffleOngoing();
error RaffleNotOpen();
error ContractNotHoldingNFT();
error InsufficientTicketsLeft();
error InsufficientTicketsBought();
error RandomNumberStillLoading();
error WinnerAlreadyChosen();
error OnlyNFTOwnerCanAccess();
error NoBalance();
error TooShort();

contract Raffle is Ownable, VRFConsumerBase {
    // Raffle Content
    address payable public nftOwner;
    uint256 public immutable ticketFee;
    uint256 public immutable startTime;
    uint256 public immutable endTime;
    uint256 public immutable minTickets;
    uint256 public ticketsBought;
    address public immutable nftContract;
    uint256 public immutable nftID;
    address payable winner;

    // Chainlink Content
    bytes32 internal keyHash;
    uint256 internal fee;
    address internal vrfCoordinator;
    address internal linkToken;
    uint256 internal randomNumber;
    bool public randomNumberRequested;

    // Player Content
    address payable[] public players;
    mapping(address => uint256) public playerTickets;

    // Events
    event RaffleEntered(
        address indexed nftID,
        address indexed player,
        uint256 numPurchased
    );
    event RaffleRefunded(
        address indexed nftID,
        address indexed player,
        uint256 numRefunded
    );
    event RaffleDeleted(address indexed nftID, address nftOwner);
    event RaffleWon(
        address indexed nftID,
        address indexed winner,
        uint256 randomNumber
    );

    constructor(
        address payable _nftOwner,
        uint256 _ticketFee,
        uint256 _timeUntilStart,
        uint256 _duration,
        uint256 _minTickets,
        address _nftContract,
        uint256 _nftID,
        bytes32 _keyHash,
        uint256 _fee
    ) Ownable() VRFConsumerBase(vrfCoordinator, linkToken) {
        nftOwner = payable(_nftOwner);
        ticketFee = _ticketFee;
        startTime = block.timestamp + _timeUntilStart;
        endTime = block.timestamp + _duration;
        minTickets = _minTickets;
        nftContract = _nftContract;
        nftID = _nftID;
        keyHash = _keyHash;
        fee = _fee;
    }

    // Only the owner of the raffle can access this function.
    modifier onlynftOwner() {
        if (msg.sender != nftOwner) {
            revert OnlyNFTOwnerCanAccess();
        }
        _;
    }

    // Function only executes if contract is holding the NFT.
    modifier nftHeld() {
        if (IERC721(nftContract).ownerOf(nftID) != address(this)) {
            revert ContractNotHoldingNFT();
        }
        _;
    }

    // Function only executes if random number was not chosen yet.
    modifier vrfCalled() {
        if (randomNumberRequested == true) {
            revert WinnerAlreadyChosen();
        }
        _;
    }

    // Function only executes if minimum ticket threshold is met
    modifier enoughTickets() {
        if (players.length < minTickets) {
            revert InsufficientTicketsBought();
        }
        _;
    }

    modifier overCheck() {
        if (block.timestamp > endTime || block.timestamp < startTime) {
            revert RaffleNotOpen();
        }
        _;
    }

    // Enter the NFT raffle
    function enterRaffle(
        uint256 _numTickets
    ) external payable nftHeld overCheck {
        if (_numTickets <= 0) {
            revert InvalidTicketAmount();
        }

        if (msg.value < ticketFee * _numTickets) {
            revert InsufficientAmount();
        }

        // Only adds player to players array if not already present
        bool found = false;
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == payable(msg.sender)) {
                found = true;
                break;
            }
        }

        if (!found) {
            players.push(payable(msg.sender));
        }

        playerTickets[msg.sender] += _numTickets;

        uint i = 0;
        uint256 totalBought;
        while (i < players.length) {
            totalBought += playerTickets[players[i]];
            i++;
        }
        ticketsBought = totalBought;

        emit RaffleEntered(nftID, msg.sender, _numTickets);
    }

    function exitRaffle(uint256 _numTickets) external nftHeld vrfCalled {
        if (
            playerTickets[msg.sender] < _numTickets ||
            playerTickets[msg.sender] == 0
        ) {
            revert InsufficientTicketsBought();
        }

        if (_numTickets == 0) {
            revert InvalidTicketAmount();
        }
        uint256 i = 0;
        while (i < players.length) {
            if (players[i] != msg.sender) {
                i++;
            } else {
                payable(msg.sender).transfer(ticketFee * _numTickets);
                playerTickets[msg.sender] -= _numTickets;

                if (playerTickets[msg.sender] == 0) {
                    players[i] = players[players.length - 1];
                    players.pop();
                }
            }
        }

        emit RaffleRefunded(nftID, msg.sender, _numTickets);
    }

    function receiveRandomWinner()
        external
        nftHeld
        enoughTickets
        vrfCalled
        overCheck
        returns (bytes32 requestId)
    {
        randomNumberRequested = true;

        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(
        bytes32 requestId,
        uint256 randomness
    ) internal override nftHeld enoughTickets {
        if (address(this).balance == 0) {
            revert NoBalance();
        }

        if (randomNumberRequested == false) {
            revert RaffleOngoing();
        }

        randomNumber = randomness;
        randomNumber = randomNumber % ticketsBought;
        uint256 ii;
        while (ii < players.length) {
            randomNumber -= playerTickets[players[ii]];

            if (randomNumber <= 0) {
                winner = payable(players[ii]);
                break;
            } else {
                ii++;
            }
        }

        payable(nftOwner).transfer((address(this).balance * 975) / 1000);
        IERC721(nftContract).safeTransferFrom(address(this), winner, nftID);
        payable(owner()).transfer((address(this).balance)); // 2.5% commission of ticket fees
        emit RaffleWon(nftID, winner, randomNumber);
    }

    function deleteRaffle() external onlynftOwner nftHeld vrfCalled {
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, nftID);

        uint256 i = 0;
        while (i < players.length) {
            payable(players[i]).transfer(ticketFee * playerTickets[players[i]]);
            i++;
        }
        emit RaffleWon(nftID, winner, randomNumber);
    }
}

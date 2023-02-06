//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Raffle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Custom Errors
error InvalidAmount();
error InsufficientLINKBalance();
error InsufficientLINKAllowance();

contract RaffleFactory is Ownable {
    uint256 public fee;
    bytes32 public keyHash;
    address public linkTokenAddress;
    address public vrfCoordinator;

    event RaffleCreated (address indexed raffle, address indexed nftOwner, address indexed nftContract, uint256 nftID, uint256 ticketPrice, uint256 minTickets);

    constructor(uint256 _fee, bytes32 _keyHash, address _linkTokenAddress, address _vrfCoordinator) Ownable() {
        fee = _fee;
        keyHash = _keyHash;
        linkTokenAddress = _linkTokenAddress;
        vrfCoordinator = _vrfCoordinator;
    }

    function createRaffle(address _nftContract, uint256 _nftID, uint256 _ticketPrice, uint256 _minTickets) external {
        if(_ticketPrice <= 0 || _minTickets == 0) {
            revert InvalidAmount();
        }

        Raffle raffle = new Raffle(payable(msg.sender), _ticketPrice, _minTickets, _nftContract, _nftID, keyHash, fee);
        emit RaffleCreated(address(raffle), msg.sender, _nftContract, _nftID, _ticketPrice, _minTickets);
        // Check if Factory is approved to spend msg.sender LINK
        // Require LINK balance of creator >= Chainlink VRF fee
    }

    function ownerWithdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
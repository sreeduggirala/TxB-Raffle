# TxB Raffle (Chainlink Version)

TxB Raffle is an NFT raffling application with ticket purchase/refund and prize disbursement capabilities; random winner selection is ensured via verifiable random functions (VRFs). 

**This project was commissioned by Shardeum to TxB Labs (Texas Blockchain's engineering cohort at UT Austin).**

# Key Features

1. NFT owners can intiate raffles with custom slots, ticket prices, and start/end dates.
2. Ticket are purchasable/refundable prior to end date.
3. NFT owners can delete raffles prior to winner selection.
4. VRF-based winner selection.
5. NFT and ticket fee pool disbursement.
6. Contract owner receives 2.5% commission.
7. Contract ownership transferability.

# Extensions/Modifications
1. ERC-20 and ERC-1155 raffles

Note: TxB Raffle is initialized to ETH Goerli Testnet; Chainlink content should be replaced with network-specific values.

Chainlink doesn't support Shardeum as of January 2023; a separe SupraOracles version will be made. 


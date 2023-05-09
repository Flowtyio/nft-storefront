# Transactions and commands to run them

## Testnet

### Commands

1. **Mint NFTs**

    ```sh
    flow transactions send ./transactions/testnet/mint_nfts.cdc 0xd9c02cdacccb25ab 10 -f ./flow.testnet.json -n testnet --signer testnet-seller
    ``` 

2. **List NFT for Sale**

    ```sh
    flow transactions send ./transactions/testnet/sell_item_via_catalog.cdc \
        FlowtyTestNFT 1.0 flowty 0.01 1686077691 \
        -n testnet -f ./flow.testnet.json --signer testnet-seller

    ```

3. Buy Item

    ```sh
    listingID="149574569"
    storefront="0x2e1dacf20102e79c"
    commission="0x86aa0c21d6fe4ead"
    signer="testnet-buyer"
    
    flow transactions send ./transactions/testnet/buy_item_via_catalog.cdc \
        FlowtyTestNFT "$listingID" "$storefront" "$commission" \
        --signer $signer -f ./flow.testnet.json -n testnet
    ```

4. Cancel Listing
    ```sh
    listingID="149574946"
    flow transactions send ./transactions/testnet/cancel_listing.cdc \
        "$listingID" --signer testnet-seller -f ./flow.testnet.json -n testnet
    ```
import DapperUtilityCoin from 0x82ec283f88a62e65
import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import NFTCatalog from 0x324c34e1c517e4db
import NFTStorefrontV2 from 0x86aa0c21d6fe4ead

import TopShot from 0x877931736ee77cff

/// Transaction used to facilitate the creation of the listing under the signer's owned storefront resource.
/// If the given nft has a support of the RoyaltyView then royalties will added as the sale cut.

transaction {
    let receiver: Capability<&AnyResource{FungibleToken.Receiver}>
    // TODO: When MetadataViews default implementation is available, use the following line.
    // let collectionCap: Capability<&AnyResource{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let collectionCap: Capability<&AnyResource{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefrontV2.Storefront
    var saleCuts: [NFTStorefrontV2.SaleCut]
    let saleItemID: UInt64
    let nftType: Type
    let expiry: UInt64
    let commissionAmount: UFix64

    prepare(acct: AuthAccount) {
        let seed = unsafeRandom()

        let firstThreeDigits = seed % 1000
        let saleItemPrice = UFix64(firstThreeDigits) * 0.01
        self.commissionAmount = saleItemPrice * 0.01

        let collectionIdentifier = "NBATopShot"
        self.expiry = UInt64(getCurrentBlock().timestamp) + 86400 // One day

        if acct.borrow<&NFTStorefrontV2.Storefront>(from: NFTStorefrontV2.StorefrontStoragePath) == nil {

            // Create a new empty Storefront
            let storefront <- NFTStorefrontV2.createStorefront() as! @NFTStorefrontV2.Storefront
            
            // save it to the account
            acct.save(<-storefront, to: NFTStorefrontV2.StorefrontStoragePath)

            // create a public capability for the Storefront
            acct.link<&NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}>(NFTStorefrontV2.StorefrontPublicPath, target: NFTStorefrontV2.StorefrontStoragePath)
        }

        let value = NFTCatalog.getCatalogEntry(collectionIdentifier: collectionIdentifier) ?? panic("Provided collection is not in the NFT Catalog.")

        self.saleCuts = []

        // We need a provider capability, but one is not provided by default so we create one if needed.
        let nftCollectionProviderPrivatePath = PrivatePath(identifier: "nftCollectionProviderForNFTStorefront".concat(collectionIdentifier))!

        // Receiver for the sale cut.
        self.receiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
        assert(self.receiver.borrow() != nil, message: "Missing or mis-typed DapperUtilityCoin receiver")

        // Check if the Provider capability exists or not if `no` then create a new link for the same.
        if !acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(nftCollectionProviderPrivatePath).check() {
            acct.unlink(nftCollectionProviderPrivatePath)
            acct.link<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(nftCollectionProviderPrivatePath, target: value.collectionData.storagePath)
        }

        self.collectionCap = acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(nftCollectionProviderPrivatePath)
        let collection = self.collectionCap.borrow<>()
            ?? panic("Could not borrow a reference to the collection")
        var totalRoyaltyCut = 0.0
        let effectiveSaleItemPrice = saleItemPrice - self.commissionAmount

        let c = acct.borrow<&{NonFungibleToken.CollectionPublic}>(from: value.collectionData.storagePath) ?? panic("no collection setup")
        let ids = c.getIDs()
        let id = seed % UInt64(ids.length)
        self.saleItemID = ids[id]

        // Append the cut for the seller.
        self.saleCuts.append(NFTStorefrontV2.SaleCut(
            receiver: self.receiver,
            amount: effectiveSaleItemPrice - totalRoyaltyCut
        ))
        assert(self.collectionCap.borrow() != nil, message: "Missing or mis-typed NonFungibleToken.Provider, NonFungibleToken.CollectionPublic provider")

        self.storefront = acct.borrow<&NFTStorefrontV2.Storefront>(from: NFTStorefrontV2.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")

        self.nftType = value.nftType
    }

    execute {
        // Create listing
        self.storefront.createListing(
            nftProviderCapability: self.collectionCap,
            nftType: self.nftType,
            nftID: self.saleItemID,
            salePaymentVaultType: Type<@DapperUtilityCoin.Vault>(),
            saleCuts: self.saleCuts,
            marketplacesCapability: nil,
            customID: "flowty",
            commissionAmount: self.commissionAmount,
            expiry: self.expiry
        )
    }
}
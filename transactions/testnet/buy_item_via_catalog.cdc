import FlowToken from 0x7e60df042a9c0868
import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import NFTCatalog from 0x324c34e1c517e4db
import NFTStorefrontV2 from 0x86aa0c21d6fe4ead

/// Transaction facilitates the purcahse of listed NFT.
/// It takes the storefront address, listing resource that need
/// to be purchased & a address that will takeaway the commission.
///
/// Buyer of the listing (,i.e. underling NFT) would authorize and sign the
/// transaction and if purchase happens then transacted NFT would store in
/// buyer's collection.

transaction(storefrontAddress: Address, listingResourceID: UInt64, commissionRecipient: Address, collectionIdentifier: String) {
    let collection: &AnyResource{NonFungibleToken.CollectionPublic}
    let storefront: &NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}
    let listing: &NFTStorefrontV2.Listing{NFTStorefrontV2.ListingPublic}
    var commissionRecipientCap: Capability<&{FungibleToken.Receiver}>?

    prepare(acct: AuthAccount) {    
        let value = NFTCatalog.getCatalogEntry(collectionIdentifier: collectionIdentifier) ?? panic("Provided collection is not in the NFT Catalog.")

        self.commissionRecipientCap = nil
        // Access the storefront public resource of the seller to purchase the listing.
        self.storefront = getAccount(storefrontAddress)
            .getCapability<&NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}>(
                NFTStorefrontV2.StorefrontPublicPath
            )!
            .borrow()
            ?? panic("Could not borrow Storefront from provided address")

        // Borrow the listing
        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
                    ?? panic("No Order with that ID in Storefront")
        let price = self.listing.getDetails().salePrice

        // Access the vault of the buyer to pay the sale price of the listing.
        let mainFlowVault = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Cannot borrow FlowToken vault from acct storage")
        let paymentVault <- mainFlowVault.withdraw(amount: price)

        // Fetch the commission amt.
        let commissionAmount = self.listing.getDetails().commissionAmount

        if commissionRecipient != nil && commissionAmount != 0.0 {
            // Access the capability to receive the commission.
            let _commissionRecipientCap = getAccount(commissionRecipient!).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            assert(_commissionRecipientCap.check(), message: "Commission Recipient doesn't have flowtoken receiving capability")
            self.commissionRecipientCap = _commissionRecipientCap
        } else if commissionAmount == 0.0 {
            self.commissionRecipientCap = nil
        } else {
            panic("Commission recipient can not be empty when commission amount is non zero")
        }

        // Purchase the NFT
        let item <- self.listing.purchase(
            payment: <-paymentVault,
            commissionRecipient: self.commissionRecipientCap
        )

        let cd = item.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

        // Deposit the NFT in the buyer's collection.
        let collectionCap = acct.getCapability<&AnyResource{NonFungibleToken.CollectionPublic}>(value.collectionData.publicPath)

        if !collectionCap.check() {
            let c <- cd.createEmptyCollection()
            acct.save(<-c, to: cd.storagePath)

            acct.unlink(cd.publicPath)
            acct.link<&{NonFungibleToken.CollectionPublic}>(cd.publicPath, target: cd.storagePath)
        }

        // Access the buyer's NFT collection to store the purchased NFT.
        self.collection = collectionCap.borrow() ?? panic("Cannot borrow NFT collection receiver from account")
        self.collection.deposit(token: <-item)
    }
}

import FlowtyTestNFT from 0xd9c02cdacccb25ab
import NonFungibleToken from 0x631e88ae7f1d7c20

transaction(royaltyRecipient: Address, num: Int) {
    let receiver: &FlowtyTestNFT.Collection{NonFungibleToken.CollectionPublic}

    prepare(acct: AuthAccount) {
        // Create account collection if not exists
        if(acct.borrow<&FlowtyTestNFT.Collection>(from: FlowtyTestNFT.CollectionStoragePath) == nil) {
            log("Setup account NFT storage")
            // Create a new empty collection
            let collection <- FlowtyTestNFT.createEmptyCollection()

            // save it to the account
            acct.save(<-collection, to: FlowtyTestNFT.CollectionStoragePath)

            // create a public capability for the collection
            acct.link<&FlowtyTestNFT.Collection{NonFungibleToken.CollectionPublic}>(
                FlowtyTestNFT.CollectionPublicPath,
                target: FlowtyTestNFT.CollectionStoragePath
            )
        }

        self.receiver = acct.borrow<&FlowtyTestNFT.Collection{NonFungibleToken.CollectionPublic}>(from: FlowtyTestNFT.CollectionStoragePath)!
    }

    execute {
        let minter = getAccount(0xd9c02cdacccb25ab).getCapability<&FlowtyTestNFT.NFTMinter>(FlowtyTestNFT.MinterPublicPath).borrow()!
        var count = 0
        while count < num {
            let totalSupply = FlowtyTestNFT.totalSupply.toString()

            minter.mintNFT(
                recipient: self.receiver
            )
            count = count + 1
        }
    }
}
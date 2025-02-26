/*
objects: helps create unique things in sui
transfer: helps us give things to people
tx_context: tells us who is doing what
coin: lets us handle money
SUI: the specific type of money used
events: helps us anounce something important is happening

*/
#[allow(duplicate_alias)]
module eugene_nft::nft {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin}; 
    use sui::sui::SUI; 
    use sui::event;
    use std::string::{String}; 

    /*
    error messages constants
    
    */
    const E_NOT_OWNER: u64 = 0;//"you are not the owner"
    const E_INVALID_ROYALTY: u64 = 1;//"thats not a valid royalty percentage"
    const E_INVALID_PAYMENT: u64 = 2;//"you didn't pay the right amount"
    const E_NOT_FOR_SALE: u64 = 3;//"This nft is not for sale"

    // NFT Toy box (struct)
    public struct NFT has key, store {
        id: UID,//a special tag that makes it unique like the toy's serial number
        name: String,//What we call the toy
        description: String,// details about the toy
        creator: address,//who made the toy
        owner: address,//who has the toy now
        royalty: u8, // Royalty percentage (0-100) how much the creator gets when the toy is sold again
    }

    // SaleListing struct to track NFTs listed for sale
    /*
    The key and store ability means the toy can be owned and traded!
    The sale sign
    who wants to sell your toy
    */
    public struct SaleListing has key, store {
        id: UID,// a unique id for this sale
        nft_id: ID,//which toy is for sale
        price: u64,//how much money you want for it
        seller: address,//who is selling the toy
    }

    // Events . Events tell us when something important is happening.
    // here we are making anouncements
    //the NFTCreated says " Hey everyone! a new toy is created"
    public struct NFTCreated has copy, drop {
        id: ID,
        name: String,
        creator: address,
    }
    // the NFTTransfered says " This toy has new owner yow!"
    public struct NFTTransferred has copy, drop {
        id: ID,
        from: address,
        to: address,
    }
    //the NFTSold saays "Someone just bought this toy" 
    public struct NFTSold has copy, drop {
        id: ID,
        seller: address,
        buyer: address,
        price: u64,
    }

    // Create a new NFT and transfer it to the caller
    // Here we are simply creating a new toy
    public entry fun create_nft(
        name: String,//what you want to call it
        description: String,// a description of what it looks like or does
        ctx: &mut TxContext//your signature to prove it's yours.
    ) {
        let nft = NFT {
            id: object::new(ctx),
            name,
            description,
            creator: tx_context::sender(ctx),
            owner: tx_context::sender(ctx),
            royalty: 0,
        };

        // Emit creation event
        event::emit(NFTCreated {
            id: object::uid_to_inner(&nft.id),
            name: nft.name,
            creator: nft.creator,
        });

        // Transfer the NFT to the caller
        transfer::public_transfer(nft, tx_context::sender(ctx));
    }

    // Transfer NFT to another address
    //Here we are giving our toy to someone else
    //we make note of who had it before (nft.owner)
    //we anounce that the toy is changing possession
    //we  give the toy to a new person
    public entry fun transfer_nft(nft: NFT, recipient: address) {
        let from = nft.owner;
        let nft_id = object::uid_to_inner(&nft.id);
        
        // Emit transfer event before transferring the NFT
        event::emit(NFTTransferred {
            id: nft_id,
            from,
            to: recipient,
        });

        // Transfer the NFT
        transfer::public_transfer(nft, recipient);
    }

    // Burn an NFT (only owner can burn)
    //Here we are throwing away our toy
    /*
    the burn_nft function lets the owner destroy their toy,
    it checks that if you really own the toy,
    then it lets you destroy it and sends an event to let everyone know
    */
    public entry fun burn_nft(nft: NFT, ctx: &mut TxContext) {
        assert!(nft.owner == tx_context::sender(ctx), E_NOT_OWNER);
        let NFT { id, name: _, description: _, creator: _, owner: _, royalty: _ } = nft;
        object::delete(id);
    }

    // Update NFT metadata (only owner can update)
    //Here its like we are changing our toy description
    /*
    The update_metadata lets you change what your toy is called and how it is described.
    it checks that you own the toy then update the toy with the new description.
    */
    public entry fun update_metadata(
        nft: &mut NFT,
        new_name: String,
        new_description: String,
        ctx: &mut TxContext
    ) {
        assert!(nft.owner == tx_context::sender(ctx), E_NOT_OWNER);
        nft.name = new_name;
        nft.description = new_description;
    }

    // Set royalty percentage (only owner can set)
    //Here we are setting how much the creator gets 
    /*
    the function set_royalty lets you decide how much of the money from a sale the creator gets.

    it does this by checking if you own the toy , makes sure that the percentage is valid
    then updates the royalty percentage
    
    */
    public entry fun set_royalty(nft: &mut NFT, royalty_percentage: u8, ctx: &mut TxContext) {
        assert!(nft.owner == tx_context::sender(ctx), E_NOT_OWNER);
        assert!(royalty_percentage <= 100, E_INVALID_ROYALTY);
        nft.royalty = royalty_percentage;
    }

    // List NFT for sale
    // Here we are putting a for sale sign on the toy
    //we check if you own the toy , then we add the toy to the list of toys for sale
    public entry fun list_for_sale(
        nft: &NFT,
        price: u64,
        ctx: &mut TxContext
    ) {
        assert!(nft.owner == tx_context::sender(ctx), E_NOT_OWNER);

        let sale_listing = SaleListing {
            id: object::new(ctx),
            nft_id: object::uid_to_inner(&nft.id),
            price,
            seller: nft.owner,
        };

        // Transfer the sale listing to the caller
        transfer::public_transfer(sale_listing, tx_context::sender(ctx));
    }

    // Buy an NFT listed for sale
    //the buy_nft function lets you buy a toy from the list of toys for sale
    /*
    it checks who is buying the toy
    it makes user the toy is really for sale 
    it checks that the person buying the toy is paying the right amount
    if there is royalty we calculate it and splits the payment into two parts
    sends the creator's share and sends the other money to the seller
    it then anounces that the toy has been sold
    gives the toy to the buyer and then removes the 'for sale' sign on the toy 
    the semicolon(;) after the if block is likely saying "am done with this thought and now lfg !
    */
    
    public entry fun buy_nft(
        sale_listing: SaleListing,
        nft: NFT,
        mut payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let buyer = tx_context::sender(ctx);
        assert!(nft.owner == sale_listing.seller, E_NOT_FOR_SALE);
        assert!(coin::value(&payment) == sale_listing.price, E_INVALID_PAYMENT);

        // Handle royalty payment
        let price = sale_listing.price;
        let royalty_percent = (nft.royalty as u64);
        
        if (royalty_percent > 0) {
            // Calculate royalty amount
            let royalty_amount = (price * royalty_percent) / 100;
            
            // Split payment for royalty
            let royalty_payment = coin::split(&mut payment, royalty_amount, ctx);
            
            // Send royalty to creator
            transfer::public_transfer(royalty_payment, nft.creator);
        };
        
        // Transfer remaining payment to seller
        transfer::public_transfer(payment, sale_listing.seller);

        // Get NFT ID for event
        let nft_id = object::uid_to_inner(&nft.id);
        
        // Emit sale event
        event::emit(NFTSold {
            id: nft_id,
            seller: sale_listing.seller,
            buyer,
            price
        });

        // Transfer the NFT to buyer
        transfer::public_transfer(nft, buyer);

        // Delete the sale listing
        let SaleListing { id, nft_id: _, price: _, seller: _ } = sale_listing;
        object::delete(id);
    }

    // Get the owner of an NFT
    //here we are looking up for information
    //who owns the toy
    public fun get_owner(nft: &NFT): address {
        nft.owner
    }

    // Get the metadata of an NFT
    //what the toy is called and its description 
    public fun get_metadata(nft: &NFT): (String, String) {
        (nft.name, nft.description)
    }
}


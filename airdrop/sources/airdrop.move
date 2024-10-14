module airdrop::me_airdrop {

    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::tx_context::TxContext;
    use sui::balance;
    use sui::transfer;

    use std::vector;
    
    // Define the structure to store the airdrop information
    public struct Airdrop<T> has store {
        admin: address,
        total_tokens: balance::Balance<T>,
        recipients: vector<address>,
    }

    // Create the airdrop resource
    public fun create_airdrop<T: store + key>(
        treasury_cap: &mut TreasuryCap<T>,
        amount: u64,
        recipients: vector<address>,
        ctx: &mut TxContext
    ): Airdrop<T> {
        let coins = coin::mint(treasury_cap, amount, ctx);
        Airdrop {
            admin: tx_context::sender(ctx),
            total_tokens: coin::into_balance(coins),
            recipients,
        }
    }

    // Distribute tokens to recipients
    public fun distribute<T: store + key>(
        airdrop: &mut Airdrop<T>,
        ctx: &mut TxContext
    ) {
        let total_recipients = vector::length(&airdrop.recipients);
        let share_per_recipient = balance::value(&airdrop.total_tokens) / total_recipients;
        let mut index = 0;
        
        while (index < total_recipients) {
            let recipient_ref = vector::borrow(&airdrop.recipients, index);
            let recipient = *recipient_ref; // Dereference to get the address
            let amount = coin::take(&mut airdrop.total_tokens, share_per_recipient, ctx);
            transfer::public_transfer(amount, recipient);
            index = index + 1;
        }
    }
}

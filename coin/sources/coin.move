module ME_TEST::ME {
		use sui::coin::{Self, TreasuryCap};
        use sui::url;
        use std::ascii::string;
		use 0x2::pay;

		public struct ME has drop {}

		fun init(witness: ME, ctx: &mut TxContext) {
				let (treasury, metadata) = coin::create_currency(witness, 4, b"ME", b"Mercury", b"Next Generation premier meme launchpad", option::some(url::new_unsafe(string(b"https://belaunchio.infura-ipfs.io/ipfs/QmcJKTJdRYUt4iACQKs1xrwrz7EUfvi15Y496KRTwCNtgU"))), ctx);
				transfer::public_freeze_object(metadata);
				transfer::public_transfer(treasury, ctx.sender())
		}

		public fun mint(
				treasury_cap: &mut TreasuryCap<ME>, 
				amount: u64,
				recipient: address, 
				ctx: &mut TxContext,
		) {
				let coin = coin::mint(treasury_cap, amount, ctx);
				transfer::public_transfer(coin, recipient)
		}
}
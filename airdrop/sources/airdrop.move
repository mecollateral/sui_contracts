module ME_TEST::Airdrop {
  use std::vector;
  use std::hash;
  
  use sui::object::{Self, UID, ID};
  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin, TreasuryCap};
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;
  use sui::clock::{Self, Clock};
  use sui::vec_map::{Self, VecMap};
  use sui::bcs;

  use ME_TEST::ME;

  
  const ENotAirdropOwner: u64 = 1;
  const ERROR_NOT_STARTED: u64 = 2;

  public struct AirdropAdminCap has key {
    id: UID
  }

  public struct Account has store {
    released: u64
  }

  public struct AirdropStorage has key { 
    id: UID,
    balance: Balance<ME::ME>,
    start: u64,
    accounts: VecMap<address, Account>
  }

  public struct AirdropOwnerCap has key { 
    id: UID,
    airdrop_storage_id: ID, 
  }

  fun init(ctx: &mut TxContext) {
    transfer::transfer(
      AirdropAdminCap {
        id: object::new(ctx)
      },
      tx_context::sender(ctx)
    );
    let airdrop_storage_uid = object::new(ctx);
    let airdrop_storage_id: ID = object::uid_to_inner(&airdrop_storage_uid);

    transfer::share_object(
      AirdropStorage {
        id: airdrop_storage_uid,
        balance: balance::zero<ME::ME>(),
        start: 0,
        accounts: vec_map::empty()
      }
    );
    transfer::transfer(AirdropOwnerCap {
          id: object::new(ctx),
          airdrop_storage_id: airdrop_storage_id,
        }, tx_context::sender(ctx));
  }


  public fun get_mut_account(storage: &mut AirdropStorage, sender: address): &mut Account {
    if (!vec_map::contains(&storage.accounts, &sender)) {
      vec_map::insert(&mut storage.accounts, sender, Account { released: 0 });
    };

    vec_map::get_mut(&mut storage.accounts, &sender)
  }


  public entry fun start(_: &AirdropAdminCap, storage: &mut AirdropStorage, coin_ipx: Coin<ME::ME>, start_time: u64) {
    balance::join(&mut storage.balance, coin::into_balance(coin_ipx));
    storage.start = start_time;
  }


  public entry fun distribute_coins(
    cap: &AirdropOwnerCap,
    storage: &mut AirdropStorage, 
    recipients: vector<address>,
    ctx: &mut TxContext
) {
    assert!(&cap.airdrop_storage_id == object::uid_as_inner(&storage.id), ENotAirdropOwner);
    let num_recipients = vector::length(&recipients);
    let share_per_recipient = balance::value(&storage.balance) / num_recipients;
    let mut i = 0;

    while (i < num_recipients) {
        let recipient = *vector::borrow(&recipients, i);
        let coin_to_send = coin::take(&mut storage.balance, share_per_recipient, ctx);
        
        transfer::public_transfer(coin_to_send, recipient);
        i = i + 1;
    }
}

}
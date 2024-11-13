module ME_TEST::ME_Launchpad {
  
  use sui::object::{Self, UID, ID};
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use sui::coin::{Self, Coin};
  use sui::balance::{Self, Balance};
  use sui::clock::{Self, Clock};
  use sui::sui::SUI;
//   use sui::event;
  use ME_TEST::ME;
  use std::vector;

  // ====== Errors ======

  const ENotLaunchpadOwner: u64 = 0;
  // Define an error code for donation amount
  const EDonationAmountZero: u64 = 1;
  const ENotStarted: u64 = 2;
  const ESaleEnded: u64 = 3;
  const ESaleInProgress: u64 = 4;
  const ETotalSuiZero: u64 = 5;
  const EInsufficientTokens: u64 = 6;
  const EOverflow: u64 = 7;
  const EVestingEnded: u64 = 8;
  const EDepositLocked: u64 = 9;
  const EDistributeLocked: u64 = 10;
  const EWithdrawLocked: u64 = 11;

  // ====== Objects ======
  
  public struct Launchpad has key {
    id: UID,
    soft_cap: u64,
    start_time: u64,
    end_time: u64,
    total_tokens: u64,
    token_balance: Balance<ME::ME>,
    deposits: vector<Deposit>,
    raised: Balance<SUI>,
    vesting_count: u8,
    lockDeposit: bool,
    lockDistribute: bool,
    lockWithdraw: bool
  }

  public struct Receipt has key, store {
    id: UID, 
    amount_donated: u64,
  }

  public struct Deposit has store {
    user: address,
    amount: u64,
  }

  // Capability that grants a fund creator the right to withdraw funds.
  public struct FundOwnerCap has key { 
    id: UID,
    launchpad_id: ID, 
  }

  // ====== Events ======

  // For when the fund target is reached.
//   struct TargetReached has copy, drop {
//     raised_amount_sui: u128,
//   }

  // ====== Functions ======

  public entry fun create_launchpad(target: u64, starttime: u64, endtime: u64, totalTokens: u64, tokenBalance: Coin<ME::ME>, ctx: &mut TxContext) {
    let launchpad_uid = object::new(ctx);
    let launchpad_id: ID = object::uid_to_inner(&launchpad_uid);

    let launchpad = Launchpad {
        id: launchpad_uid,
        soft_cap: target,
        start_time: starttime,
        end_time: endtime,
        total_tokens: totalTokens,
        token_balance: coin::into_balance(tokenBalance),
        deposits: vector::empty(),
        raised: balance::zero(),
        vesting_count: 1,
        lockDeposit: false,
        lockDistribute: true,
        lockWithdraw: true
    };

    // create and send a fund owner capability for the creator
     transfer::transfer(FundOwnerCap {
          id: object::new(ctx),
          launchpad_id: launchpad_id,
        }, tx_context::sender(ctx));

    // share the object so anyone can donate
    transfer::share_object(launchpad);
  }

  // public entry fun deposit(launchpad: &mut Launchpad, user: address, coinId: &mut Coin<SUI>, amount: u64, clock: &Clock, ctx: &mut TxContext) {
  //     //current time
  //     let current_time = clock::timestamp_ms(clock);

  //     //start time check
  //     // assert!(current_time >= launchpad.start_time, ENotStarted);

  //     //start time check
  //     // assert!(current_time <= launchpad.end_time, ESaleEnded);

  //     // Check if the amount to donate is greater than zero
  //     assert!(amount > 0, EDonationAmountZero);

  //     // Split the coin and transfer the specified amount
  //     let add_amount = coin::split(coinId, amount, ctx);
  //     let add_balance = coin::into_balance(add_amount);
  //     balance::join(&mut launchpad.raised, add_balance);

  //     // Get the total raised amount so far in SUI
  //   //   let raised_amount_sui = (balance::value(&launchpad.raised) as u128);

  //     // Emit event that the target has been reached
  //   //   event::emit(TargetReached { raised_amount_sui });

  //     // Create and send receipt NFT to the donor (for tax purposes)
  //     let receipt: Receipt = Receipt {
  //         id: object::new(ctx), 
  //         amount_donated: amount,
  //     };

  //     let deposit = Deposit { user, amount };
  //     vector::push_back(&mut launchpad.deposits, deposit);

  //     transfer::public_transfer(receipt, tx_context::sender(ctx));
  // }

  public entry fun deposit(
      launchpad: &mut Launchpad,
      user: address,
      coinId: &mut Coin<SUI>,
      amount: u64,
      clock: &Clock,
      ctx: &mut TxContext
  ) {
      let current_time = clock::timestamp_ms(clock);

      assert!(!launchpad.lockDeposit, EDepositLocked);

       //start time check
       // assert!(current_time >= launchpad.start_time, ENotStarted);

       //start time check
       // assert!(current_time <= launchpad.end_time, ESaleEnded);

      assert!(amount > 0, EDonationAmountZero);

      let add_amount = coin::split(coinId, amount, ctx);
      let add_balance = coin::into_balance(add_amount);
      balance::join(&mut launchpad.raised, add_balance);

      // Check if the user already has a deposit
      let num_deposits = vector::length(&launchpad.deposits);
      let mut i = 0;
      let mut found = false;

      while (i < num_deposits) {
          let deposit = vector::borrow_mut(&mut launchpad.deposits, i);
          if (deposit.user == user) {
              deposit.amount = deposit.amount + amount;
              found = true;
              break;
          };
          i = i + 1;
      };

      // If no existing deposit was found, add a new one
      if (!found) {
          let new_deposit = Deposit { user, amount };
          vector::push_back(&mut launchpad.deposits, new_deposit);
      };

      let receipt: Receipt = Receipt {
          id: object::new(ctx), 
          amount_donated: amount,
      };

      transfer::public_transfer(receipt, tx_context::sender(ctx));
  }

  public entry fun distribute_coins(
      cap: &FundOwnerCap,
      launchpad: &mut Launchpad,
      clock: &Clock,
      ctx: &mut TxContext
  ) {
      assert!(&cap.launchpad_id == object::uid_as_inner(&launchpad.id), ENotLaunchpadOwner);

      assert!(!launchpad.lockDistribute, EDistributeLocked);
      // Current time
      let current_time = clock::timestamp_ms(clock);
      let mut percentage = 0;

      // Ensure the sale has ended
      // assert!(current_time > launchpad.end_time, ESaleInProgress);

      let total_sui = balance::value(&launchpad.raised) as u128;
      assert!(total_sui > 0, ETotalSuiZero);
      if(launchpad.vesting_count == 1) {
          percentage = 5;
          launchpad.vesting_count = 2;
      } else if(launchpad.vesting_count == 2) {
          percentage = 10;
          launchpad.vesting_count = 3;
      } else if(launchpad.vesting_count == 3) {
          percentage = 10;
          launchpad.vesting_count = 4;
      } else if(launchpad.vesting_count == 4) {
          percentage = 10;
          launchpad.vesting_count = 5;
      } else if(launchpad.vesting_count == 5) {
          percentage = 10;
          launchpad.vesting_count = 6;
      } else if(launchpad.vesting_count == 6) {
          percentage = 10;
          launchpad.vesting_count = 7;
      } else if(launchpad.vesting_count == 7) {
          percentage = 10;
          launchpad.vesting_count = 8;
      } else if(launchpad.vesting_count == 8) {
          percentage = 10;
          launchpad.vesting_count = 9;
      } else if(launchpad.vesting_count == 9) {
          percentage = 10;
          launchpad.vesting_count = 10;
      } else if(launchpad.vesting_count == 10) {
          percentage = 15;
          launchpad.vesting_count = 11;
      } else {
          assert!(false, EVestingEnded);
      };

      let total_tokens = launchpad.total_tokens as u128;
      let num_recipients = vector::length(&launchpad.deposits);
      let mut i = 0;

      while (i < num_recipients) {
          let deposit = vector::borrow(&launchpad.deposits, i);
          let recipient = deposit.user;

          // Calculate user share safely
          let user_share = (deposit.amount as u128 * (total_tokens * percentage)) / (total_sui * 100);

          // Ensure the result fits within a u64
          assert!(user_share <= (1 << 64) - 1, EOverflow);

          // Ensure there are enough tokens to send
          assert!(balance::value(&launchpad.token_balance) >= user_share as u64, EInsufficientTokens);

          let coin_to_send = balance::split(&mut launchpad.token_balance, user_share as u64);
          let coin = coin::from_balance(coin_to_send, ctx);
            transfer::public_transfer(coin, recipient);

            i = i + 1; // Increment i
      }
  }

  // withdraw funds from the fund contract, requires a fund owner capability that matches the fund id
  public entry fun withdraw_funds(cap: &FundOwnerCap, launchpad: &mut Launchpad, ctx: &mut TxContext) {

    assert!(&cap.launchpad_id == object::uid_as_inner(&launchpad.id), ENotLaunchpadOwner);

    assert!(!launchpad.lockWithdraw, EWithdrawLocked);

    let amount: u64 = balance::value(&launchpad.raised);

    let raised: Coin<SUI> = coin::take(&mut launchpad.raised, amount, ctx);

    transfer::public_transfer(raised, tx_context::sender(ctx));
    
  }

  public entry fun depositKey(cap: &FundOwnerCap, launchpad: &mut Launchpad, lockStatus: bool, ctx: &mut TxContext) {

    assert!(&cap.launchpad_id == object::uid_as_inner(&launchpad.id), ENotLaunchpadOwner);

    launchpad.lockDeposit = lockStatus;
  }

  public entry fun distributeKey(cap: &FundOwnerCap, launchpad: &mut Launchpad, lockStatus: bool, ctx: &mut TxContext) {

    assert!(&cap.launchpad_id == object::uid_as_inner(&launchpad.id), ENotLaunchpadOwner);

    launchpad.lockDistribute = lockStatus;
  }

  public entry fun withdrawKey(cap: &FundOwnerCap, launchpad: &mut Launchpad, lockStatus: bool, ctx: &mut TxContext) {

    assert!(&cap.launchpad_id == object::uid_as_inner(&launchpad.id), ENotLaunchpadOwner);

    launchpad.lockWithdraw = lockStatus;
  }

  public entry fun change_softcap(cap: &FundOwnerCap, launchpad: &mut Launchpad, value: u64, ctx: &mut TxContext) {

    assert!(&cap.launchpad_id == object::uid_as_inner(&launchpad.id), ENotLaunchpadOwner);

    launchpad.soft_cap = value;
  }

}
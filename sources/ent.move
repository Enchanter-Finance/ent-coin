module ent::ent {
    use std::string;
    use std::signer;
    use aptos_framework::coin::{Self, BurnCapability, MintCapability, Coin};
    use aptos_framework::timestamp::now_seconds;
    use std::string::String;
    use aptos_framework::event;
    use aptos_framework::account;
    use aptos_framework::timestamp;

    /// coin DECIMALS
    const DECIMALS: u8 = 8;
    /// pow(10,8) = 10**8
    const DECIMAL_TOTAL: u64 = 100000000;
    /// 100 million
    const MAX_SUPPLY_AMOUNT: u64 = 100000000;
    /// 15%
    const DEV_TEAM: u64 = 15000000 ;
    /// 10%
    const INVESTORS: u64 = 10000000 ;
    /// 3%
    const ADVISORS: u64 = 3000000 ;
    /// 15%
    const FOUNDATION: u64 = 15000000;
    /// 57%
    const COMMUNITY: u64 = 57000000;


    /// Error codes
    const ERR_NOT_ADMIN: u64 = 0x10004;
    const ERR_TIME_ERROR: u64 = 0x10005;
    const ERR_CANT_LARGE_BANK_VALUE: u64 = 0x10006;
    const ERR_CANT_LARGE_BANK_SUPPLY: u64 = 0x10007;
    const ERR_CANT_LARGE_BANK_RELEASE: u64 = 0x10008;

    /// ENT Coin
    struct ENT has key, store {}

    /// store Capability for mint and  burn
    struct CapStore has key {
        mint_cap: MintCapability<ENT>,
        burn_cap: BurnCapability<ENT>,
    }


    /// genesis info
    struct GenesisInfo has key, store {
        /// seconds
        genesis_time: u64,
        /// withdraw bank event
        withdraw_event: event::EventHandle<WithdrawBankEvent>
    }

    /// bank for  community
    struct CommunityBank has key, store { value: Coin<ENT> }

    /// bank for  dev team
    struct DevTeamBank has key, store { value: Coin<ENT> }

    /// bank for  investor
    struct InvestorsBank has key, store { value: Coin<ENT> }

    /// bank for  advisors
    struct AdvisorsBank has key, store { value: Coin<ENT> }

    /// bank for  foundation
    struct FoundationBank has key, store { value: Coin<ENT> }


    /// It must be initialized first
    public entry fun init(signer: &signer) {
        assert_admin_signer(signer);
        let (burn_cap, freeze_cap, mint_cap) =
            coin::initialize<ENT>(signer, string::utf8(b"Enchanter Coin"), string::utf8(b"ENT"), DECIMALS, true);
        coin::destroy_freeze_cap(freeze_cap);
        coin::register<ENT>(signer);

        let mint_coins = coin::mint<ENT>(MAX_SUPPLY_AMOUNT * DECIMAL_TOTAL, &mint_cap);
        move_to(signer, CommunityBank { value: coin::extract(&mut mint_coins, COMMUNITY * DECIMAL_TOTAL) });
        move_to(signer, DevTeamBank { value: coin::extract(&mut mint_coins, DEV_TEAM * DECIMAL_TOTAL) });
        move_to(signer, InvestorsBank { value: coin::extract(&mut mint_coins, INVESTORS * DECIMAL_TOTAL) });
        move_to(signer, FoundationBank { value: coin::extract(&mut mint_coins, FOUNDATION * DECIMAL_TOTAL) });
        move_to(signer, AdvisorsBank { value: mint_coins });

        move_to(signer, CapStore { mint_cap, burn_cap });
        move_to(signer, GenesisInfo { genesis_time: now_seconds(), withdraw_event: account::new_event_handle<WithdrawBankEvent>(signer) });
    }


    /// Burn ENT
    public fun burn(token: coin::Coin<ENT>) acquires CapStore {
        coin::burn<ENT>(token, &borrow_global<CapStore>(@ent).burn_cap)
    }


    /// withdraw community bank
    public entry fun withdraw_community(account: &signer, to: address, amount: u64) acquires CommunityBank, GenesisInfo {
        assert_admin_signer(account);
        let bank = borrow_global_mut<CommunityBank>(@ent);
        assert_deposit_amount(amount, coin::value(&bank.value), COMMUNITY * DECIMAL_TOTAL);
        coin::deposit<ENT>(to, coin::extract<ENT>(&mut bank.value, amount));
        emit_withdraw_event(to, amount, string::utf8(b"community"));
    }

    /// withdraw dev team bank
    public entry fun withdraw_team(account: &signer, to: address, amount: u64) acquires DevTeamBank, GenesisInfo {
        assert_admin_signer(account);
        let bank = borrow_global_mut<DevTeamBank>(@ent);
        assert_deposit_amount(amount, coin::value(&bank.value), DEV_TEAM * DECIMAL_TOTAL);
        coin::deposit<ENT>(to, coin::extract<ENT>(&mut bank.value, amount));
        emit_withdraw_event(to, amount, string::utf8(b"team"));
    }

    /// withdraw foundation bank
    public entry fun withdraw_foundation(account: &signer, to: address, amount: u64) acquires GenesisInfo, FoundationBank {
        assert_admin_signer(account);
        let bank = borrow_global_mut<FoundationBank>(@ent);
        assert_deposit_amount(amount, coin::value(&bank.value), FOUNDATION * DECIMAL_TOTAL);
        coin::deposit<ENT>(to, coin::extract<ENT>(&mut bank.value, amount));
        emit_withdraw_event(to, amount, string::utf8(b"foundation"));
    }

    /// withdraw investors bank
    public entry fun withdraw_investors(account: &signer, to: address, amount: u64) acquires InvestorsBank, GenesisInfo {
        assert_admin_signer(account);
        let bank = borrow_global_mut<InvestorsBank>(@ent);
        assert_deposit_amount(amount, coin::value(&bank.value), INVESTORS * DECIMAL_TOTAL);
        coin::deposit<ENT>(to, coin::extract<ENT>(&mut bank.value, amount));
        emit_withdraw_event(to, amount, string::utf8(b"investors"));
    }

    /// withdraw advisors bank
    public entry fun withdraw_advisors(account: &signer, to: address, amount: u64) acquires AdvisorsBank, GenesisInfo {
        assert_admin_signer(account);
        let bank = borrow_global_mut<AdvisorsBank>(@ent);
        assert_deposit_amount(amount, coin::value(&bank.value), ADVISORS * DECIMAL_TOTAL);
        coin::deposit<ENT>(to, coin::extract<ENT>(&mut bank.value, amount));
        emit_withdraw_event(to, amount, string::utf8(b"advisors"));
    }


    /// deposit to bank
    public entry fun deposit_community(account: &signer, amount: u64) acquires CommunityBank {
        coin::merge<ENT>(&mut borrow_global_mut<CommunityBank>(@ent).value, coin::withdraw<ENT>(account, amount));
    }

    public entry fun deposit_team(account: &signer, amount: u64) acquires DevTeamBank {
        coin::merge<ENT>(&mut borrow_global_mut<DevTeamBank>(@ent).value, coin::withdraw<ENT>(account, amount));
    }

    public entry fun deposit_investors(account: &signer, amount: u64)  acquires InvestorsBank {
        coin::merge<ENT>(&mut borrow_global_mut<InvestorsBank>(@ent).value, coin::withdraw<ENT>(account, amount));
    }

    public entry fun deposit_foundation(account: &signer, amount: u64) acquires FoundationBank {
        coin::merge<ENT>(&mut borrow_global_mut<FoundationBank>(@ent).value, coin::withdraw<ENT>(account, amount));
    }

    public entry fun deposit_advisors(account: &signer, amount: u64) acquires AdvisorsBank {
        coin::merge<ENT>(&mut borrow_global_mut<AdvisorsBank>(@ent).value, coin::withdraw<ENT>(account, amount));
    }


    /// register ENT to sender
    public entry fun register(account: &signer) { coin::register<ENT>(account); }


    /// helper must admin
    fun assert_admin_signer(sign: &signer) { assert!(signer::address_of(sign) == @ent, ERR_NOT_ADMIN); }

    /// helper release rule
    fun assert_deposit_amount(amount: u64, bank_value: u64, supply: u64) acquires GenesisInfo {
        assert!(bank_value >= amount, ERR_CANT_LARGE_BANK_VALUE);
        let info = borrow_global<GenesisInfo>(@ent);
        let now = timestamp::now_seconds();
        assert!(now > info.genesis_time, ERR_TIME_ERROR);
        let max = max_release(get_day(info.genesis_time, now), supply);
        assert!(supply >= max, ERR_CANT_LARGE_BANK_SUPPLY);
        assert!((bank_value - amount) >= (supply - max), ERR_CANT_LARGE_BANK_RELEASE);
    }


    /// get day form diff time
    fun get_day(start: u64, end: u64): u64 { ((end - start) / 86400) + 1 }


    /// get max release from day and supply
    public fun max_release(day: u64, supply: u64): u64 {
        // 1% per day
        if (day <= 10) { supply * day / 100 }
        //  0.16% per day  +   supply / 10 = 10%
        // 16 / 10000 =  0.0016%
        else if (day <= 100) { supply * (day - 10) / 625 + (supply / 10) }
        //  0.1% per day   + (supply * 244 / 1000) = 24.4%
        else if (day <= 200) { supply * (day - 100) / 1000 + (supply * 244 / 1000) }
        // 0.05% per day  + (supply * 344 / 1000) = 34.4%
        // 1/2000 = 0.0005
        else if (day <= 1000) { supply * (day - 200) / 2000 + (supply * 344 / 1000) }
        // 0.025% per day +  (supply * 744 / 1000) = 74.4%
        // 1 / 4000 =  0.025%
        else if (day <= 2024) { supply * (day - 1000) / 4000 + (supply * 744 / 1000) }
        // all
        else if (day > 2024) { supply }
        else { 0 }
    }


    struct WithdrawBankEvent has drop, store {
        /// to address
        to: address,
        /// withdraw amount
        amount: u64,
        /// coin type
        bank_name: String,
    }


    /// emit withdraw event
    fun emit_withdraw_event(to: address, amount: u64, bank_name: String)acquires GenesisInfo {
        event::emit_event(&mut borrow_global_mut<GenesisInfo>(@ent).withdraw_event, WithdrawBankEvent { to, amount, bank_name });
    }


    #[test]
    fun test_max_release() {
        let max = max_release(1, 10000000);
        assert!(max == 100000, max);
        let max = max_release(10, 10000000);
        assert!(max == 1000000, max);

        let max = max_release(11, 10000000);
        assert!(max == 1016000, max);

        let max = max_release(12, 10000000);
        assert!(max == 1032000, max);

        let max = max_release(99, 10000000);
        assert!(max == 2424000, max);

        let max = max_release(100, 10000000);
        assert!(max == 2440000, max);


        let max = max_release(150, 10000000);
        assert!(max == 2940000, max);

        let max = max_release(200, 10000000);
        assert!(max == 3440000, max);


        let max = max_release(700, 10000000);
        assert!(max == 5940000, max);

        let max = max_release(1000, 10000000);
        assert!(max == 7440000, max);


        let max = max_release(1001, 10000000);
        assert!(max == 7442500, max);


        let max = max_release(1024, 10000000);
        assert!(max == 7500000, max);


        let max = max_release(2024, 10000000);
        assert!(max == 10000000, max);

        let max = max_release(3000, 10000000);
        assert!(max == 10000000, max);


        let max = max_release(30000, 10000000);
        assert!(max == 10000000, max);
    }

    #[test]
    fun test_max_release_2() {
        let max = max_release(1, 10000000 * DECIMAL_TOTAL);
        assert!(max == 100000 * DECIMAL_TOTAL, max);
        let max = max_release(10, 10000000 * DECIMAL_TOTAL);
        assert!(max == 1000000 * DECIMAL_TOTAL, max);

        let max = max_release(11, 10000000 * DECIMAL_TOTAL);
        assert!(max == 1016000 * DECIMAL_TOTAL, max);

        let max = max_release(12, 10000000 * DECIMAL_TOTAL);
        assert!(max == 1032000 * DECIMAL_TOTAL, max);

        let max = max_release(99, 10000000 * DECIMAL_TOTAL);
        assert!(max == 2424000 * DECIMAL_TOTAL, max);

        let max = max_release(100, 10000000 * DECIMAL_TOTAL);
        assert!(max == 2440000 * DECIMAL_TOTAL, max);


        let max = max_release(150, 10000000 * DECIMAL_TOTAL);
        assert!(max == 2940000 * DECIMAL_TOTAL, max);

        let max = max_release(200, 10000000 * DECIMAL_TOTAL);
        assert!(max == 3440000 * DECIMAL_TOTAL, max);


        let max = max_release(700, 10000000 * DECIMAL_TOTAL);
        assert!(max == 5940000 * DECIMAL_TOTAL, max);

        let max = max_release(1000, 10000000 * DECIMAL_TOTAL);
        assert!(max == 7440000 * DECIMAL_TOTAL, max);


        let max = max_release(1001, 10000000 * DECIMAL_TOTAL);
        assert!(max == 7442500 * DECIMAL_TOTAL, max);


        let max = max_release(1024, 10000000 * DECIMAL_TOTAL);
        assert!(max == 7500000 * DECIMAL_TOTAL, max);


        let max = max_release(2024, 10000000 * DECIMAL_TOTAL);
        assert!(max == 10000000 * DECIMAL_TOTAL, max);

        let max = max_release(3000, 10000000 * DECIMAL_TOTAL);
        assert!(max == 10000000 * DECIMAL_TOTAL, max);


        let max = max_release(30000, 10000000 * DECIMAL_TOTAL);
        assert!(max == 10000000 * DECIMAL_TOTAL, max);
    }


    #[test]
    fun test_max_release_3() {
        let max = max_release(1, 100000000 * DECIMAL_TOTAL);
        assert!(max == 1000000 * DECIMAL_TOTAL, max);
        let max = max_release(10, 100000000 * DECIMAL_TOTAL);
        assert!(max == 10000000 * DECIMAL_TOTAL, max);

        let max = max_release(11, 100000000 * DECIMAL_TOTAL);
        assert!(max == 10160000 * DECIMAL_TOTAL, max);

        let max = max_release(12, 100000000 * DECIMAL_TOTAL);
        assert!(max == 10320000 * DECIMAL_TOTAL, max);

        let max = max_release(99, 100000000 * DECIMAL_TOTAL);
        assert!(max == 24240000 * DECIMAL_TOTAL, max);

        let max = max_release(100, 100000000 * DECIMAL_TOTAL);
        assert!(max == 24400000 * DECIMAL_TOTAL, max);


        let max = max_release(150, 100000000 * DECIMAL_TOTAL);
        assert!(max == 29400000 * DECIMAL_TOTAL, max);

        let max = max_release(200, 100000000 * DECIMAL_TOTAL);
        assert!(max == 34400000 * DECIMAL_TOTAL, max);


        let max = max_release(700, 100000000 * DECIMAL_TOTAL);
        assert!(max == 59400000 * DECIMAL_TOTAL, max);

        let max = max_release(1000, 100000000 * DECIMAL_TOTAL);
        assert!(max == 74400000 * DECIMAL_TOTAL, max);


        let max = max_release(1001, 100000000 * DECIMAL_TOTAL);
        assert!(max == 74425000 * DECIMAL_TOTAL, max);


        let max = max_release(1024, 100000000 * DECIMAL_TOTAL);
        assert!(max == 75000000 * DECIMAL_TOTAL, max);


        let max = max_release(2024, 100000000 * DECIMAL_TOTAL);
        assert!(max == 100000000 * DECIMAL_TOTAL, max);

        let max = max_release(3000, 100000000 * DECIMAL_TOTAL);
        assert!(max == 100000000 * DECIMAL_TOTAL, max);


        let max = max_release(30000, 100000000 * DECIMAL_TOTAL);
        assert!(max == 100000000 * DECIMAL_TOTAL, max);
    }


    #[test]
    fun test_max_release_4() {
        let max = max_release(1, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 570000 * DECIMAL_TOTAL, max);
        let max = max_release(10, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 5700000 * DECIMAL_TOTAL, max);

        let max = max_release(11, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 5791200 * DECIMAL_TOTAL, max);

        let max = max_release(12, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 5882400 * DECIMAL_TOTAL, max);

        let max = max_release(99, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 13816800 * DECIMAL_TOTAL, max);

        let max = max_release(100, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 13908000 * DECIMAL_TOTAL, max);


        let max = max_release(150, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 16758000 * DECIMAL_TOTAL, max);

        let max = max_release(200, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 19608000 * DECIMAL_TOTAL, max);


        let max = max_release(700, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 33858000 * DECIMAL_TOTAL, max);

        let max = max_release(1000, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 42408000 * DECIMAL_TOTAL, max);


        let max = max_release(1001, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 42422250 * DECIMAL_TOTAL, max);


        let max = max_release(1024, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 42750000 * DECIMAL_TOTAL, max);

        let max = max_release(2000, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 56658000 * DECIMAL_TOTAL, max);

        let max = max_release(2024, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 57000000 * DECIMAL_TOTAL, max);

        let max = max_release(3000, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 57000000 * DECIMAL_TOTAL, max);


        let max = max_release(30000, COMMUNITY * DECIMAL_TOTAL);
        assert!(max == 57000000 * DECIMAL_TOTAL, max);
    }


    #[test]
    fun test_supply() {
        assert!(MAX_SUPPLY_AMOUNT == DEV_TEAM + FOUNDATION + INVESTORS + ADVISORS + COMMUNITY, 1)
    }

    #[test]
    fun test_get_day() {
        let day = get_day(1666108266, 1666108266 + 3600);
        assert!(day == 1, day);

        let day = get_day(1666108266, 1666108266 + 24 * 3600);
        assert!(day == 2, day);

        let day = get_day(1666108266, 1666108266 + 3 * 24 * 3600);
        assert!(day == 4, day);

        let day = get_day(1666108266, 1666108266 + 1000 * 24 * 3600 + 3600);
        assert!(day == 1001, day);
    }
}


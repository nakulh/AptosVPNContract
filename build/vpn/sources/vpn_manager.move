module vpn_registery::vpn_manager {
    use std::error;
    use std::vector;
    use std::signer::{Self};
    use std::string::{Self, String};
    use aptos_framework::aptos_account;
    use aptos_framework::event;
    use aptos_framework::coin;
    use aptos_framework::object::{Self, DeleteRef, ExtendRef, Object, ObjectCore};

    const E_NOT_OWNER: u64 = 1;
    const E_NOT_PUBLISHER: u64 = 2;
    const E_NOT_ALLOWED_TO_DELETE: u64 = 3;
    
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct VpnProvider has key {
        name: String,
        network_address: String,
        seller: address,
        price: u64,
        extend_ref: object::ExtendRef,
        delete_ref: object::DeleteRef
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
        struct ObjectController has key {
        extend_ref: object::ExtendRef,
        delete_ref: object::DeleteRef
    }

    #[event]
    struct VPNCreatedEvent has drop, store {
        name: String,
        network_address: String,
        seller: address,
        price: u64,
        //objAddress: address
    }

    #[event]
    struct VPNDeletedEvent has drop, store {
        name: String,
        network_address: String,
        seller: address,
        objAddress: address
    }

    #[event]
    struct VPNUpdatedEvent has drop, store {
        name: String,
        network_address: String,
        seller: address,
        price: u64,
        objAddress: address
    }

    

    entry fun create_vpn_provider(caller: &signer, name: String, network_address: String, price: u64) {
        let caller_address = signer::address_of(caller);
        let constructor_ref = object::create_object(caller_address);

        // Retrieves a signer for the object
        let object_signer = object::generate_signer(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let delete_ref = object::generate_delete_ref(&constructor_ref);

        let newVPNProvider = VpnProvider { 
            name, 
            network_address, 
            seller: signer::address_of(caller),
            price,
            extend_ref,
            delete_ref
        };
        move_to(&object_signer, newVPNProvider);

        let vpnCreatedEvent = VPNCreatedEvent {
            name,
            network_address,
            seller: signer::address_of(caller),
            price,
            //objAddress: object::object_address(&newVPNProvider)
        };
        0x1::event::emit(vpnCreatedEvent);
    }

    entry fun delete(caller: &signer, object: Object<VpnProvider>) acquires VpnProvider {
        let caller_address = signer::address_of(caller);
        let allowed_to_delete = false;

        let allowed_addresses: vector<address> = vector::singleton<address>(@0xbd2497fc645660a5c4a3e0739c0d5fb7ca68e2f717d2ac35280054c907b1db6e);
        let length_of_validator_addresses = vector::length(&allowed_addresses);
        for (i in 0..length_of_validator_addresses) {
            let current_validator_address: &address = vector::borrow(&allowed_addresses, i);
            if (current_validator_address == &caller_address) {
                allowed_to_delete = true;
                break;
            }
        };
        if (object::is_owner(object, caller_address)) {
            allowed_to_delete = true;
        };
        assert!(allowed_to_delete, E_NOT_ALLOWED_TO_DELETE);
        
        let object_address = object::object_address(&object);
        let VpnProvider {
            name, 
            network_address, 
            seller,
            price,
            extend_ref,
            delete_ref
        } = move_from<VpnProvider>(
            object_address
        );
        object::delete(delete_ref);
        let vpnDeleted = VPNDeletedEvent {
            name,
            network_address,
            seller,
            objAddress: object_address
        };
        0x1::event::emit(vpnDeleted);
    }

    entry fun purchase<CoinType>(purchaser: &signer, object: Object<ObjectCore>) acquires VpnProvider {
        let listing_addr = object::object_address(&object);
        let price = borrow_global<VpnProvider>(listing_addr).price;
        let seller = borrow_global<VpnProvider>(listing_addr).seller;
        let coins = coin::withdraw<CoinType>(purchaser, price);
        aptos_account::deposit_coins(seller, coins);
    }

    entry fun modifyVPNAddress(caller: &signer, object: Object<VpnProvider>, newAddress: String) acquires VpnProvider {
        let caller_address = signer::address_of(caller);
        assert!(object::is_owner(object, caller_address), E_NOT_OWNER);
        let object_address = object::object_address(&object);
        let caller_vpn = borrow_global_mut<VpnProvider>(object_address);
        caller_vpn.network_address = newAddress;
        let vpnUpdatedEvent = VPNUpdatedEvent {
            name: caller_vpn.name,
            network_address: newAddress,
            seller: caller_address,
            price: caller_vpn.price,
            objAddress: object::object_address(&object)
        };
        0x1::event::emit(vpnUpdatedEvent);
    }
}

//aptos move publish --skip-fetch-latest-git-deps --named-addresses vpn_registery=default
//aptos move compile --skip-fetch-latest-git-deps --named-addresses vpn_registery=default
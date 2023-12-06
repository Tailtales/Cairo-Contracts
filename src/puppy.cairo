use starknet::ContractAddress;

#[starknet::interface]
trait IERC721<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
    fn get_symbol(self: @TContractState) -> felt252;

    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn balance_of(self: @TContractState, owner: ContractAddress) -> u256;
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(self: @TContractState, owner: ContractAddress, operator: ContractAddress) -> bool;

    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256);
}

#[starknet::interface]
trait IPuppy<TContractState> {
    fn exists(self: @TContractState, token_id: u256) -> bool;
    fn mint(ref self: TContractState) -> u256;
    fn breed(ref self: TContractState, parent_1_id: u256, parent_2_id: u256) -> u256;
    fn token_uri(self: @TContractState, token_id: u256) -> felt252;
    fn pet(ref self: TContractState, token_id: u256);
    fn is_alive(self: @TContractState, token_id: u256) -> bool;
    fn max_token_id(self: @TContractState) -> u256;
    fn bury(ref self: TContractState, token_id: u256);
}

#[starknet::contract]
mod Puppy {
    use core::traits::Into;
    use core::zeroable::Zeroable;
    use starknet::ContractAddress;
    use starknet::info::{get_block_number, get_caller_address, get_block_timestamp};


    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        balances: LegacyMap<ContractAddress, u256>,
        owners: LegacyMap<u256, ContractAddress>,
        approvals: LegacyMap<u256, ContractAddress>,
        approvals_for_all: LegacyMap<(ContractAddress, ContractAddress), bool>,
        total_genosis_available: u256,
        current_token_id: u256,
        random_seeds: LegacyMap<u256, felt252>,
        last_active: LegacyMap<u256, u64>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        ApprovalForAll: ApprovalForAll,
    }

    /// Emitted when `token_id` token is transferred from `from` to `to`.
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        #[key]
        token_id: u256
    }

    /// Emitted when `owner` enables `approved` to manage the `token_id` token.
    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        approved: ContractAddress,
        #[key]
        token_id: u256
    }

    /// Emitted when `owner` enables or disables (`approved`) `operator` to manage
    /// all of its assets.
    #[derive(Drop, starknet::Event)]
    struct ApprovalForAll {
        #[key]
        owner: ContractAddress,
        #[key]
        operator: ContractAddress,
        approved: bool
    }

    #[constructor]
    fn constructor(ref self: ContractState,
        total_genosis_available: u256,
    ) {
        let caller = get_caller_address();
        self.symbol.write('ERC721');
        self.name.write('ERC721');
        self.total_genosis_available.write(total_genosis_available);
        // self.random_seeds.write(caller, 1);
    }

    #[abi(embed_v0)]
    impl ERC721Impl of super::IERC721<ContractState> {
        fn get_name(self: @ContractState) -> felt252 {
            self.name.read()
        }
        fn get_symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.owners.read(token_id);
            assert(!owner.is_zero(), 'Token does not exist');
            
            owner
        }

        fn balance_of(self: @ContractState, owner: ContractAddress) -> u256 {
            self.balances.read(owner)
        }

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(!self.owners.read(token_id).is_zero(), 'Token does not exist');
            
            self.approvals.read(token_id)
        }

        fn is_approved_for_all(self: @ContractState, owner: ContractAddress, operator: ContractAddress) -> bool {
            assert(!owner.is_zero(), 'Zero address');
            assert(!operator.is_zero(), 'Zero address');
            assert(owner != operator, 'Same address');

            self.approvals_for_all.read((owner, operator))
        }

        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let caller = get_caller_address();
            assert(self.owner_of(token_id) == caller, 'Unauthorized');
            assert(to != caller, 'Same address');
            assert(self.approvals.read(token_id) != to, 'Already approved');
            self.approvals.write(token_id, to);

            self.emit(Approval { owner: caller, approved: to, token_id });
        }

        fn set_approval_for_all(ref self: ContractState, operator: ContractAddress, approved: bool) {
            let caller = get_caller_address();
            assert(caller != operator, 'Same address');
            assert(self.approvals_for_all.read((caller, operator)) != approved, 'Already the same status');
            self.approvals_for_all.write((caller, operator), approved);

            self.emit(ApprovalForAll { owner: caller, operator, approved });
        }

        fn transfer_from(ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256) {
            self.assert_alive(token_id);
            assert(self.owners.read(token_id) == from, 'Unauthorized');
            assert(from != to, 'Same address');

            let caller = get_caller_address();
            if (caller == from) {
                assert(self.owners.read(token_id) == caller, 'Unauthorized');
            } else {
                assert(self.approvals.read(token_id) == caller || self.approvals_for_all.read((from, caller)), 'Unauthorized');
            }

            self.owners.write(token_id, to);
            self.balances.write(from, self.balances.read(from) - 1);
            self.balances.write(to, self.balances.read(to) + 1);
            self.approvals.write(token_id, Zeroable::zero());

            self.emit(Transfer { from, to, token_id });
        }
    }

    #[abi(embed_v0)]
    impl PuppyImpl of super::IPuppy<ContractState> {
        fn mint(ref self: ContractState) -> u256 {
            let total_genosis_available = self.total_genosis_available.read();
            assert(total_genosis_available > 0, 'No more genosis available');
            self.total_genosis_available.write(total_genosis_available - 1);

            let caller = get_caller_address();
            let random_number = self._generate_random_number();

            self._mint(caller, random_number)
        }

        fn breed(ref self: ContractState, parent_1_id: u256, parent_2_id: u256) -> u256 {
            self.assert_alive(parent_1_id);
            self.assert_alive(parent_2_id);            
            self.assert_ownership(parent_1_id);
            self.assert_ownership(parent_2_id);
            assert(parent_1_id != parent_2_id, 'Same token');
            
            let caller = get_caller_address();
            let random_number: u256 = (self._generate_random_number().into() + self.random_seeds.read(parent_1_id).into() + self.random_seeds.read(parent_1_id).into()) / 3;

            self._mint(caller, random_number.try_into().unwrap())
        }

        fn token_uri(self: @ContractState, token_id: u256) -> felt252 {
            self.assert_exists(token_id);
            
            self.random_seeds.read(token_id)
        }

        fn pet(ref self: ContractState, token_id: u256) {
            self.assert_ownership(token_id);
            
            // TODO: give some reward tokens to the user for petting their pet

            let current_timestamp = get_block_timestamp();
            self.last_active.write(token_id, current_timestamp);
        }

        fn exists(self: @ContractState, token_id: u256) -> bool {
            !self.owners.read(token_id).is_zero()
        }

        fn is_alive(self: @ContractState, token_id: u256) -> bool {
            self.assert_exists(token_id);

            let last_active = self.last_active.read(token_id);
            let current_timestamp = get_block_timestamp();
            let time_escaped = current_timestamp - last_active;
            let threshold = 30 * 60; // 3 minutes
            time_escaped <= threshold
        }

        fn max_token_id(self: @ContractState) -> u256 {
            self.current_token_id.read()
        }

        fn bury(ref self: ContractState, token_id: u256) {
            self.assert_exists(token_id);
            assert(!self.is_alive(token_id), 'Pet is still alive');

            self._burn(token_id);

            // TODO: give some reward to the user who buried the puppy
        }
    }

    #[generate_trait]
    impl Private of PrivateTrait {
        fn assert_alive(self: @ContractState, token_id: u256) {
            assert(self.is_alive(token_id), 'Pet died');
        }

        fn assert_exists(self: @ContractState, token_id: u256) {
            assert(self.exists(token_id), 'Pet does not exists');
        }

        fn assert_ownership(self: @ContractState, token_id: u256) {
            self.assert_exists(token_id);
            let caller =  get_caller_address();
            assert(self.owners.read(token_id) == caller, 'Unauthorized');
        }

        
        fn _mint(ref self: ContractState, to: ContractAddress, random_number: felt252) -> u256 {
            assert(!to.is_zero(), 'Zero address');
            
            let token_id = self.current_token_id.read() + 1;
            self.current_token_id.write(token_id);
            self.owners.write(token_id, to);
            self.balances.write(to, self.balances.read(to) + 1);
            self.random_seeds.write(token_id, random_number);

            let current_timestamp = get_block_timestamp();
            self.last_active.write(token_id, current_timestamp);

            self.emit(Transfer { from: Zeroable::zero(), to, token_id });

            token_id
        }

        fn _burn(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();

            self.owners.write(token_id, Zeroable::zero());
            self.balances.write(caller, self.balances.read(caller) - 1);
            self.approvals.write(token_id, Zeroable::zero());

            self.emit(Transfer { from: caller, to: Zeroable::zero(), token_id });
        }

        fn _generate_random_number(self: @ContractState) -> felt252 {
            let timestamp: felt252 = get_block_timestamp().into();
            let seed_token_id = self.current_token_id.read() + 1;
            pedersen::pedersen(timestamp, seed_token_id.try_into().unwrap())
        }
    }
}
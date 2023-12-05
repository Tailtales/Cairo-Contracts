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

#[starknet::contract]
mod ERC721 {
    use core::zeroable::Zeroable;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        balances: LegacyMap<ContractAddress, u256>,
        owners: LegacyMap<u256, ContractAddress>,
        approvals: LegacyMap<u256, ContractAddress>,
        approvals_for_all: LegacyMap<(ContractAddress, ContractAddress), bool>,
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
    ) {
        let caller = get_caller_address();
        self.symbol.write('ERC721');
        self.name.write('ERC721');
        self._mint(caller, 1);
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
            let caller = get_caller_address();
            assert(caller == from, 'Unauthorized');
            assert(from != to, 'Same address');
            assert(self.owners.read(token_id) == from, 'Unauthorized');
            assert(self.approvals.read(token_id) == caller || self.approvals_for_all.read((from, caller)), 'Unauthorized');
            self.owners.write(token_id, to);
            self.balances.write(from, self.balances.read(from) - 1);
            self.balances.write(to, self.balances.read(to) + 1);

            self.emit(Transfer { from, to, token_id });
        }
    }

    #[generate_trait]
    impl Private of PrivateTrait {
        fn _mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            assert(!to.is_zero(), 'Zero address');
            assert(self.owners.read(token_id).is_zero(), 'Token already minted');
            self.owners.write(token_id, to);
            self.balances.write(to, self.balances.read(to) + 1);

            self.emit(Transfer { from: Zeroable::zero(), to, token_id });
        }

        fn _burn(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();
            assert(self.owners.read(token_id) == caller, 'Unauthorized');
            self.owners.write(token_id, Zeroable::zero());
            self.balances.write(caller, self.balances.read(caller) - 1);

            self.emit(Transfer { from: caller, to: Zeroable::zero(), token_id });
        }
    }
}
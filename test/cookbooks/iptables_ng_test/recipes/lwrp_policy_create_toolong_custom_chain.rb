iptables_ng_policy 'create-toolong-custom-chain' do
  table  'mangle'
  chain  'THIS_IS_WAY_TOO_LONG_FOR_AN_IPTABLES_CHAIN_NAME'
  policy 'DROP [0:0]'
  action :create
end

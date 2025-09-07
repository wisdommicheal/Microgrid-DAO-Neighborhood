;; title: microgrid-dao

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_MEMBER (err u101))
(define-constant ERR_INSUFFICIENT_ENERGY (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u104))
(define-constant ERR_ALREADY_VOTED (err u105))
(define-constant ERR_VOTING_PERIOD_ENDED (err u106))
(define-constant ERR_PROPOSAL_NOT_PASSED (err u107))
(define-constant ERR_ALREADY_MEMBER (err u108))

(define-data-var next-proposal-id uint u1)
(define-data-var total-energy-pool uint u0)
(define-data-var energy-price uint u10)
(define-data-var voting-period uint u1440)

(define-map members 
  principal 
  {
    energy-produced: uint,
    energy-consumed: uint,
    reputation-score: uint,
    joined-at: uint,
    is-active: bool
  }
)

(define-map energy-records
  {producer: principal, block: uint}
  {amount: uint, timestamp: uint}
)

(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    proposal-type: (string-ascii 20),
    target-value: uint,
    yes-votes: uint,
    no-votes: uint,
    end-block: uint,
    executed: bool
  }
)

(define-map votes
  {proposal-id: uint, voter: principal}
  {vote: bool, voting-power: uint}
)

(define-map energy-trades
  uint
  {
    seller: principal,
    buyer: principal,
    amount: uint,
    price: uint,
    completed: bool,
    created-at: uint
  }
)

(define-data-var next-trade-id uint u1)

(define-read-only (get-member-info (member principal))
  (map-get? members member)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-energy-price)
  (var-get energy-price)
)

(define-read-only (get-total-energy-pool)
  (var-get total-energy-pool)
)

(define-read-only (get-voting-period)
  (var-get voting-period)
)

(define-read-only (is-member (address principal))
  (match (map-get? members address)
    member-data (get is-active member-data)
    false
  )
)

(define-read-only (get-member-reputation (member principal))
  (match (map-get? members member)
    member-data (get reputation-score member-data)
    u0
  )
)

(define-public (join-dao)
  (let ((existing-member (map-get? members tx-sender)))
    (if (is-some existing-member)
      ERR_ALREADY_MEMBER
      (begin
        (map-set members tx-sender {
          energy-produced: u0,
          energy-consumed: u0,
          reputation-score: u100,
          joined-at: stacks-block-height,
          is-active: true
        })
        (ok true)
      )
    )
  )
)

(define-public (record-energy-production (amount uint))
  (let (
    (current-member (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
    (current-block stacks-block-height)
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get is-active current-member) ERR_NOT_MEMBER)
    
    (map-set energy-records
      {producer: tx-sender, block: current-block}
      {amount: amount, timestamp: stacks-block-height}
    )
    
    (map-set members tx-sender (merge current-member {
      energy-produced: (+ (get energy-produced current-member) amount),
      reputation-score: (+ (get reputation-score current-member) (/ amount u10))
    }))
    
    (var-set total-energy-pool (+ (var-get total-energy-pool) amount))
    (ok amount)
  )
)

(define-public (consume-energy (amount uint))
  (let (
    (current-member (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
    (available-energy (var-get total-energy-pool))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get is-active current-member) ERR_NOT_MEMBER)
    (asserts! (>= available-energy amount) ERR_INSUFFICIENT_ENERGY)
    
    (map-set members tx-sender (merge current-member {
      energy-consumed: (+ (get energy-consumed current-member) amount)
    }))
    
    (var-set total-energy-pool (- available-energy amount))
    (ok amount)
  )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (proposal-type (string-ascii 20)) (target-value uint))
  (let (
    (proposal-id (var-get next-proposal-id))
    (current-member (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
  )
    (asserts! (get is-active current-member) ERR_NOT_MEMBER)
    (asserts! (>= (get reputation-score current-member) u50) ERR_UNAUTHORIZED)
    
    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      proposal-type: proposal-type,
      target-value: target-value,
      yes-votes: u0,
      no-votes: u0,
      end-block: (+ stacks-block-height (var-get voting-period)),
      executed: false
    })
    
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (voter-member (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
    (existing-vote (map-get? votes {proposal-id: proposal-id, voter: tx-sender}))
    (voting-power (get reputation-score voter-member))
  )
    (asserts! (get is-active voter-member) ERR_NOT_MEMBER)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (asserts! (<= stacks-block-height (get end-block proposal)) ERR_VOTING_PERIOD_ENDED)
    
    (map-set votes {proposal-id: proposal-id, voter: tx-sender} {
      vote: vote,
      voting-power: voting-power
    })
    
    (map-set proposals proposal-id (merge proposal {
      yes-votes: (if vote (+ (get yes-votes proposal) voting-power) (get yes-votes proposal)),
      no-votes: (if vote (get no-votes proposal) (+ (get no-votes proposal) voting-power))
    }))
    
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
    (passed (> (get yes-votes proposal) (get no-votes proposal)))
  )
    (asserts! (> stacks-block-height (get end-block proposal)) ERR_VOTING_PERIOD_ENDED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_NOT_FOUND)
    (asserts! passed ERR_PROPOSAL_NOT_PASSED)
    (asserts! (> total-votes u0) ERR_PROPOSAL_NOT_PASSED)
    
    (map-set proposals proposal-id (merge proposal {executed: true}))
    
    (if (is-eq (get proposal-type proposal) "price-change")
      (var-set energy-price (get target-value proposal))
      (if (is-eq (get proposal-type proposal) "voting-period")
        (var-set voting-period (get target-value proposal))
        true
      )
    )
    
    (ok true)
  )
)

(define-public (create-energy-trade (amount uint) (price uint))
  (let (
    (trade-id (var-get next-trade-id))
    (seller-member (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
    (available-energy (- (get energy-produced seller-member) (get energy-consumed seller-member)))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> price u0) ERR_INVALID_AMOUNT)
    (asserts! (get is-active seller-member) ERR_NOT_MEMBER)
    (asserts! (>= available-energy amount) ERR_INSUFFICIENT_ENERGY)
    
    (map-set energy-trades trade-id {
      seller: tx-sender,
      buyer: tx-sender,
      amount: amount,
      price: price,
      completed: false,
      created-at: stacks-block-height
    })
    
    (var-set next-trade-id (+ trade-id u1))
    (ok trade-id)
  )
)

(define-public (buy-energy (trade-id uint))
  (let (
    (trade (unwrap! (map-get? energy-trades trade-id) ERR_PROPOSAL_NOT_FOUND))
    (buyer-member (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
    (seller-member (unwrap! (map-get? members (get seller trade)) ERR_NOT_MEMBER))
  )
    (asserts! (get is-active buyer-member) ERR_NOT_MEMBER)
    (asserts! (not (get completed trade)) ERR_PROPOSAL_NOT_FOUND)
    (asserts! (not (is-eq tx-sender (get seller trade))) ERR_UNAUTHORIZED)
    
    (map-set energy-trades trade-id (merge trade {
      buyer: tx-sender,
      completed: true
    }))
    
    (map-set members tx-sender (merge buyer-member {
      energy-consumed: (+ (get energy-consumed buyer-member) (get amount trade))
    }))
    
    (map-set members (get seller trade) (merge seller-member {
      reputation-score: (+ (get reputation-score seller-member) u5)
    }))
    
    (ok true)
  )
)

(define-public (update-member-status (member principal) (active bool))
  (let ((member-data (unwrap! (map-get? members member) ERR_NOT_MEMBER)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set members member (merge member-data {is-active: active}))
    (ok true)
  )
)

(define-read-only (get-member-energy-balance (member principal))
  (match (map-get? members member)
    member-data 
      (ok (- (get energy-produced member-data) (get energy-consumed member-data)))
    ERR_NOT_MEMBER
  )
)

(define-read-only (get-proposal-votes (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal-data
      (ok {
        yes-votes: (get yes-votes proposal-data),
        no-votes: (get no-votes proposal-data),
        total-votes: (+ (get yes-votes proposal-data) (get no-votes proposal-data))
      })
    ERR_PROPOSAL_NOT_FOUND
  )
)

(define-read-only (get-trade (trade-id uint))
  (map-get? energy-trades trade-id)
)

;; CharityDistribution DAO Contract
;; A transparent charity platform with community voting on fund allocation and impact tracking
;; Define the fungible token for governance
(define-fungible-token charity-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-proposal-not-found (err u104))
(define-constant err-already-voted (err u105))
(define-constant err-voting-closed (err u106))

;; Data Variables
(define-data-var proposal-counter uint u0)
(define-data-var total-charity-funds uint u0)
(define-data-var voting-period uint u1000) ;; blocks

;; Data Maps

(define-map charity-proposals 
  uint 
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    recipient: principal,
    amount: uint,
    votes-for: uint,
    votes-against: uint,
    creator: principal,
    created-at: uint,
    status: (string-ascii 20) ;; "active", "approved", "rejected", "executed"
  }
)

(define-map member-votes 
  {proposal-id: uint, voter: principal}
  {vote: bool, voting-power: uint}
)

(define-map member-contributions principal uint)

;; Function 1: Create Charity Proposal
;; Allows community members to propose charity fund allocations
(define-public (create-charity-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (recipient principal)
  (amount uint))
  (let 
    ((proposal-id (+ (var-get proposal-counter) u1))
     (current-block block-height))
    (begin
      ;; Validate inputs
      (asserts! (> amount u0) err-invalid-amount)
      (asserts! (<= amount (var-get total-charity-funds)) err-insufficient-balance)
      
      ;; Create the proposal
      (map-set charity-proposals proposal-id
        {
          title: title,
          description: description,
          recipient: recipient,
          amount: amount,
          votes-for: u0,
          votes-against: u0,
          creator: tx-sender,
          created-at: current-block,
          status: "active"
        })
      
      ;; Update proposal counter
      (var-set proposal-counter proposal-id)
      
      ;; Print event for transparency
      (print {
        event: "proposal-created",
        proposal-id: proposal-id,
        creator: tx-sender,
        recipient: recipient,
        amount: amount
      })
      
      (ok proposal-id))))

;; Function 2: Vote on Charity Proposal
;; Allows token holders to vote on charity proposals with their governance tokens
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let 
    ((voter-balance (ft-get-balance charity-token tx-sender))
     (proposal (unwrap! (map-get? charity-proposals proposal-id) err-proposal-not-found))
     (vote-key {proposal-id: proposal-id, voter: tx-sender})
     (current-block block-height))
    (begin
      ;; Check if proposal exists and is active
      (asserts! (is-eq (get status proposal) "active") err-voting-closed)
      
      ;; Check voting period (proposal must be within voting period)
      (asserts! (<= current-block (+ (get created-at proposal) (var-get voting-period))) err-voting-closed)
      
      ;; Check if user has already voted
      (asserts! (is-none (map-get? member-votes vote-key)) err-already-voted)
      
      ;; Check if user has voting power (token balance)
      (asserts! (> voter-balance u0) err-not-authorized)
      
      ;; Record the vote
      (map-set member-votes vote-key
        {vote: vote-for, voting-power: voter-balance})
      
      ;; Update proposal vote counts
      (map-set charity-proposals proposal-id
        (merge proposal
          (if vote-for
            {votes-for: (+ (get votes-for proposal) voter-balance)}
            {votes-against: (+ (get votes-against proposal) voter-balance)})))
      
      ;; Auto-execute if proposal reaches threshold (simple majority)
      (let ((updated-proposal (unwrap-panic (map-get? charity-proposals proposal-id))))
        (if (> (get votes-for updated-proposal) (get votes-against updated-proposal))
          (begin
            ;; Mark as approved if majority reached
            (map-set charity-proposals proposal-id
              (merge updated-proposal {status: "approved"}))
            
            ;; Print approval event
            (print {
              event: "proposal-approved",
              proposal-id: proposal-id,
              votes-for: (get votes-for updated-proposal),
              votes-against: (get votes-against updated-proposal)
            }))
          ;; Keep as active
          true))
      
      (ok true))))

;; Read-only functions for transparency

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? charity-proposals proposal-id)).












  

;; Get vote details
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? member-votes {proposal-id: proposal-id, voter: voter}))

;; Get total charity funds available
(define-read-only (get-total-charity-funds)
  (ok (var-get total-charity-funds)))

;; Get member contribution
(define-read-only (get-member-contribution (member principal))
  (default-to u0 (map-get? member-contributions member)))

;; Get current proposal count
(define-read-only (get-proposal-count)
  (ok (var-get proposal-counter)))

;; Administrative functions (for initial setup and fund management)

;; Initialize charity funds (owner only)
(define-public (add-charity-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-charity-funds (+ (var-get total-charity-funds) amount))
    
    ;; Track member contribution
    (map-set member-contributions tx-sender 
      (+ (get-member-contribution tx-sender) amount))
    
    (print {event: "funds-added", amount: amount, total: (var-get total-charity-funds)})
    (ok true)))

;; Mint governance tokens for contributors
(define-public (mint-governance-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (ft-mint? charity-token amount recipient))
    (ok true)))
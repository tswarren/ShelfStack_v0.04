# Phase 7A Test Coverage Matrix

Maps Phase 7A test-plan scenarios to automated tests. Updated after gap-closure pass.

| Scenario area | Test file |
| --- | --- |
| Customer lookup | `test/services/customers/customer_lookup_test.rb` |
| Request match context | `test/services/customers/request_match_context_test.rb` |
| Match variant | `test/services/customer_requests/match_variant_test.rb` |
| Request create / header status | `test/services/customer_requests/create_test.rb`, `header_status_resolver_test.rb` |
| Notify surfacing | `test/services/customer_requests/surface_notify_lines_test.rb` |
| Notify queue filter | `test/services/customer_requests/notify_queue_query_test.rb` |
| On-hand reserve | `test/services/inventory_reservations/reserve_on_hand_test.rb` |
| PO line demand breakdown | `test/services/purchasing/purchase_order_line_demand_breakdown_test.rb` |
| Receipt customer-reserved qty | `test/services/purchasing/receipt_line_demand_test.rb` |
| POS add reservation line | `test/services/pos/add_reservation_line_test.rb` |
| POS pickup integration | `test/integration/phase7a_pos_pickup_integration_test.rb` |
| Customers workspace | `test/integration/customers_workspace_integration_test.rb` |
| Request match handoff | `test/integration/customers_request_match_integration_test.rb` |
| Request queues | `test/integration/customers_request_queues_test.rb` |
| Items operations demand panel | `test/presenters/items/customer_demand_operations_test.rb` |
| Expire reservations rake | `test/tasks/inventory_rake_test.rb` |
| Expire job | `test/jobs/inventory_reservations/expire_job_test.rb` |

Manual / deferred: automated SMS/email, deposits, gift-card tenders, inter-store fulfillment.

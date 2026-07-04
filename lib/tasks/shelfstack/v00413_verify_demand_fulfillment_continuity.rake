# frozen_string_literal: true

namespace :shelfstack do
  desc "Verify v0.04-13 demand-to-fulfillment continuity (set V00413_SLICE=slice_0|slice_a|...|final|readiness)"
  task "v00413:verify_demand_fulfillment_continuity": :environment do
    Shelfstack::V00413Verify.run!
  end
end

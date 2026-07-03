# frozen_string_literal: true

namespace :shelfstack do
  desc "Verify v0.04-12 demand ordering UX (set V00412_SLICE=slice_b|slice_a|...|final)"
  task "v00412:verify_demand_ordering_ux": :environment do
    Shelfstack::V00412Verify.run!
  end
end

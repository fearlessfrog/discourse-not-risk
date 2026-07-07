# frozen_string_literal: true

RSpec.describe PrettyText do
  before { SiteSetting.not_risk_enabled = true }

  it "cooks a not-risk placeholder into a safe mount point" do
    cooked = PrettyText.cook("[not-risk game=123]")

    expect(cooked).to include('class="not-risk-game"')
    expect(cooked).to include('data-game-id="123"')
    expect(cooked).not_to include("<script")
  end
end

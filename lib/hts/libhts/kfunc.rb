# frozen_string_literal: true

module HTS
  module LibHTS
    # Log gamma function
    attach_function \
      :kf_lgamma,
      [:double],
      :double

    # complementary error function
    attach_function \
      :kf_erfc,
      [:double],
      :double

    # The following computes regularized incomplete gamma functions.
    attach_function \
      :kf_gammap,
      %i[double double],
      :double

    attach_function \
      :kf_gammaq,
      %i[double double],
      :double

    attach_function \
      :kf_betai,
      %i[double double double],
      :double

    attach_function \
      :kt_fisher_exact,
      %i[int int int int pointer pointer pointer],
      :double
  end
end

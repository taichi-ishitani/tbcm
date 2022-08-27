package tbcm_matrix_arbiter_pkg;
  typedef enum logic [2:0] {
    TBCM_MATRIX_ARBITER_FIXED_PRIORITY,
    TBCM_MATRIX_ARBITER_INCREMENTAL_ROUND_ROBIN,
    TBCM_MATRIX_ARBITER_DECREMENTAL_ROUND_ROBIN,
    TBCM_MATRIX_ARBITER_LRG,
    TBCM_MATRIX_ARBITER_MRG
  } tbcm_matrix_arbiter_type;
endpackage

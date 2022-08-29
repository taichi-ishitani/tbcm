module tbcm_matrix_arbiter
  import  tbcm_matrix_arbiter_pkg::*;
#(
  parameter int                               REQUESTS          = 2,
  parameter bit                               KEEP_RESULT       = 1,
  parameter bit [REQUESTS-1:0][REQUESTS-1:0]  INITIAL_PRIORITY  = '1
)(
  input   var                               clk,
  input   var                               rst_n,
  input   var                               i_reset_priority,
  input   var [REQUESTS-1:0][REQUESTS-1:0]  i_initial_priority,
  input   var tbcm_matrix_arbiter_type      i_arbiter_type,
  input   var [REQUESTS-1:0]                i_request,
  output  var [REQUESTS-1:0]                o_grant,
  input   var [REQUESTS-1:0]                i_free
);
  logic [REQUESTS-1:0][REQUESTS-1:0]  priority_matrix;
  logic [REQUESTS-1:0]                request;
  logic [1:0][REQUESTS-1:0]           grant;
  logic                               grab_grant;
  logic                               busy;

  always_comb begin
    o_grant = grant[1];
  end

  always_comb begin
    request     = (!busy) ? i_request : '0;
    grab_grant  = request != '0;
  end

  if (KEEP_RESULT) begin : g_result
    logic [REQUESTS-1:0]  grant_latched;

    always_comb begin
      grant[1]  =
        ((grab_grant) ? grant[0]      : '0) |
        ((busy      ) ? grant_latched : '0);
    end

    always_ff @(posedge clk, negedge rst_n) begin
      if (!rst_n) begin
        busy  <= '0;
      end
      else if ((grant[1] & i_free) != '0) begin
        busy  <= '0;
      end
      else if (grab_grant) begin
        busy  <= '1;
      end
    end

    always_ff @(posedge clk, negedge rst_n) begin
      if (!rst_n) begin
        grant_latched <= '0;
      end
      else if (grab_grant) begin
        grant_latched <= grant[0];
      end
    end
  end
  else begin : g_result
    always_comb begin
      grant[1]  = (grab_grant) ? grant[0] : '0;
    end

    always_comb begin
      busy  = '0;
    end
  end

//--------------------------------------------------------------
//  Priority matrix
//--------------------------------------------------------------
  if (1) begin : g_priority_matrix
    logic [REQUESTS-1:0][REQUESTS-1:0]  priority_matrix_next;

    always_comb begin
      grant[0]              = compute_grant(request, priority_matrix);
      priority_matrix_next  = update_priority_matrix(i_arbiter_type, priority_matrix, grant[0]);
    end

    for (genvar row = 0;row < REQUESTS;++row) begin : g_row
      for (genvar column = 0;column < REQUESTS;++column) begin : g_column
        if (column == row) begin : g
          always_comb begin
            priority_matrix[row][column]  = i_arbiter_type == TBCM_MATRIX_ARBITER_INCREMENTAL_ROUND_ROBIN;
          end
        end
        else if (column < row) begin : g
          always_comb begin
            priority_matrix[row][column]  = !priority_matrix[column][row];
          end
        end
        else begin : g
          always_ff @(posedge clk, negedge rst_n) begin
            if (!rst_n) begin
              priority_matrix[row][column]  <= INITIAL_PRIORITY[row][column];
            end
            else if (i_reset_priority) begin
              priority_matrix[row][column]  <= i_initial_priority[row][column];
            end
            else if (grab_grant) begin
              priority_matrix[row][column]  <= priority_matrix_next[row][column];
            end
          end
        end
      end
    end
  end

  function automatic logic [REQUESTS-1:0] compute_grant(
    logic [REQUESTS-1:0]                request,
    logic [REQUESTS-1:0][REQUESTS-1:0]  priority_matrix
  );
    logic [REQUESTS-1:0]  grant;

    for (int i = 0;i < REQUESTS;++i) begin
      logic [REQUESTS-1:0]  column;

      for (int j = 0;j < REQUESTS;++j) begin
        column[j] = (i != j) && request[j] && priority_matrix[j][i];
      end

      grant[i]  = request[i] && (column == '0);
    end

    return grant;
  endfunction

  function automatic logic [REQUESTS-1:0][REQUESTS-1:0] update_priority_matrix(
    tbcm_matrix_arbiter_type            arbiter_type,
    logic [REQUESTS-1:0][REQUESTS-1:0]  priority_matrix,
    logic [REQUESTS-1:0]                grant
  );
    logic [REQUESTS-1:0]                update_position;
    logic                               row_value;
    logic                               column_value;
    logic [REQUESTS-1:0][REQUESTS-1:0]  priority_matrix_next;

    case (arbiter_type)
      TBCM_MATRIX_ARBITER_INCREMENTAL_ROUND_ROBIN: begin
        for (int i = 0;i < REQUESTS;++i) begin
          update_position[i]  = priority_matrix[i] == '1;
        end
        row_value     = '0;
        column_value  = '1;
      end
      TBCM_MATRIX_ARBITER_DECREMENTAL_ROUND_ROBIN: begin
        for (int i = 0;i < REQUESTS;++i) begin
          update_position[i]  = priority_matrix[i] == '0;
        end
        row_value     = '1;
        column_value  = '0;
      end
      TBCM_MATRIX_ARBITER_LRG: begin
        update_position = grant;
        row_value       = '0;
        column_value    = '1;
      end
      TBCM_MATRIX_ARBITER_MRG: begin
        update_position = grant;
        row_value       = '1;
        column_value    = '0;
      end
      default: begin
        update_position = '0;
        row_value       = '0;
        column_value    = '0;
      end
    endcase

    priority_matrix_next  = priority_matrix;
    for (int i = 0;i < REQUESTS;++i) begin
      for (int j = i + 1;j < REQUESTS;++j) begin
        if (update_position[j]) begin
          priority_matrix_next[i][j]  = column_value;
        end
        else if (update_position[i]) begin
          priority_matrix_next[i][j]  = row_value;
        end
      end
    end

    return priority_matrix_next;
  endfunction

`ifndef SYNTHESIS
  int                                       row_values[REQUESTS];
  int                                       column_values[REQUESTS];
  bit [REQUESTS-1:0][$clog2(REQUESTS)-1:0]  priority_values;

  always_comb begin
    for (int i = 0;i < REQUESTS;++i) begin
      bit [REQUESTS-1:0]  row;
      bit [REQUESTS-1:0]  column;

      row = priority_matrix[i];
      for (int j = 0;j < REQUESTS;++j) begin
        column[j] = priority_matrix[j][i];
      end

      row_values[i]       = $countones(row) - row[i];
      column_values[i]    = $countones(column) - column[i];
      priority_values[i]  = row_values[i];
    end
  end

  function automatic bit is_unique(int array[REQUESTS]);
    int q[$];
    q = array.unique;
    return q.size() == REQUESTS;
  endfunction

  property p_row_values_should_be_unique;
    @(posedge clk) disable iff (!rst_n)
    is_unique(row_values);
  endproperty

  property p_column_values_should_be_unique;
    @(posedge clk) disable iff (!rst_n)
    is_unique(column_values);
  endproperty

  property p_grant_should_be_onehot;
    @(posedge clk) disable iff (!rst_n)
    (request != '0) |-> $countones(grant[0]) == 1;
  endproperty

  property p_grant_should_be_for_active_request;
    @(posedge clk) disable iff (!rst_n)
    (request != '0) |-> ((request & grant[0]) != '0);
  endproperty

  property p_grant_should_be_kept_while_busy;
    @(posedge clk) disable iff (!rst_n)
    busy |-> grant[1] == $past(grant[1]);
  endproperty

  property p_grant_should_be_low_during_idle;
    @(posedge clk) disable iff (!rst_n)
    ((i_request == '0) && (!busy)) |-> (grant[1] == '0);
  endproperty

  ast_row_values_should_be_unique:
  assert property(p_row_values_should_be_unique);

  ast_column_values_should_be_unique:
  assert property(p_column_values_should_be_unique);

  ast_grant_should_be_onehot:
  assert property(p_grant_should_be_onehot);

  ast_grant_should_be_for_active_request:
  assert property(p_grant_should_be_for_active_request);

  ast_grant_should_be_kept_while_busy:
  assert property(p_grant_should_be_kept_while_busy);

  ast_grant_should_be_low_during_idle:
  assert property(p_grant_should_be_low_during_idle);
`endif
endmodule

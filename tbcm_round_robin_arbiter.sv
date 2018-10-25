module tbcm_round_robin_arbiter #(
  parameter int                 REQUESTS      = 2,
  parameter bit                 KEEP_RESULT   = 1,
  parameter bit [REQUESTS-1:0]  INITIAL_GRANT = 1
)(
  input   logic                 clk,
  input   logic                 rst_n,
  input   logic [REQUESTS-1:0]  i_request,
  output  logic [REQUESTS-1:0]  o_grant,
  input   logic [REQUESTS-1:0]  i_free
);
  logic                 busy;
  logic                 grab_grant;
  logic [REQUESTS-1:0]  grant;
  logic [REQUESTS-1:0]  current_grant;
  logic [REQUESTS-1:0]  grant_next;
  logic [REQUESTS-1:0]  grant_next_each[REQUESTS];

//--------------------------------------------------------------
//  State
//--------------------------------------------------------------
  if (KEEP_RESULT) begin
    always_ff @(posedge clk, negedge rst_n) begin
      if (!rst_n) begin
        busy  <= '0;
      end
      else if ((grant & i_free) != '0) begin
        busy  <= '0;
      end
      else if (grab_grant) begin
        busy  <= '1;
      end
    end
  end
  else begin
    assign  busy  = '0;
  end

//--------------------------------------------------------------
//  Generating Grant
//--------------------------------------------------------------
  assign  o_grant     = grant;
  assign  grant       = (grab_grant) ? grant_next
                      : (busy      ) ? current_grant : '0;
  assign  grant_next  = merge_grant_next(grant_next_each);
  assign  grab_grant  = |(i_request & {REQUESTS{~busy}});
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      current_grant <= INITIAL_GRANT;
    end
    else if (grab_grant) begin
      current_grant <= grant_next;
    end
  end

  for (genvar i = 0;i < REQUESTS;++i) begin : g_grant_next
    assign  grant_next_each[i]  = get_grant(i_request, current_grant[i], i);
  end

  function automatic logic [REQUESTS-1:0] merge_grant_next(
    input logic [REQUESTS-1:0] grant_next_each[REQUESTS]
  );
    logic [REQUESTS-1:0]  grant_next;
    grant_next  = grant_next_each[0];
    for (int i = 1;i < REQUESTS;++i) begin
      grant_next  = grant_next | grant_next_each[i];
    end
    return grant_next;
  endfunction

  function automatic logic [REQUESTS-1:0] get_grant(
    input logic [REQUESTS-1:0]  request,
    input logic                 current_grant,
    input int                   index
  );
    logic [1*REQUESTS-1:0]  request_masked;
    logic [2*REQUESTS-1:0]  request_temp;
    logic [1*REQUESTS-1:0]  request_rearranged;
    logic [1*REQUESTS-1:0]  grant;
    logic [2*REQUESTS-1:0]  grant_temp;
    request_masked      = (current_grant) ? request : '0;
    request_temp        = {request_masked, request_masked};
    request_rearranged  = request_temp[index+1+:REQUESTS];
    grant               = request_rearranged & (~(request_rearranged + '1));
    grant_temp          = {grant, grant};
    return grant_temp[REQUESTS-1-index+:REQUESTS];
  endfunction
endmodule

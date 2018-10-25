module tbcm_mux #(
  parameter   int   WIDTH         = 2,
  parameter   type  DATA_TYPE     = logic [WIDTH-1:0],
  parameter   int   ENTRIES       = 2,
  parameter   bit   ONE_HOT       = 1,
  localparam  int   SELECT_WIDTH  = (ONE_HOT) ? ENTRIES : $clog2(ENTRIES)
)(
  input   logic [SELECT_WIDTH-1:0]  i_select,
  input   DATA_TYPE                 i_data[ENTRIES],
  output  DATA_TYPE                 o_data
);
  localparam  int DATA_WIDTH  = $bits(DATA_TYPE);

  if (ONE_HOT) begin : g_one_hot
    assign  o_data  = one_hot_mux(i_select, i_data);
  end
  else begin : g_binary
    assign  o_data  = i_data[i_select];
  end

  function automatic DATA_TYPE one_hot_mux(
    input logic [ENTRIES-1:0] select,
    input DATA_TYPE           in_data[ENTRIES]
  );
    DATA_TYPE out_data;
    out_data  = {DATA_WIDTH{select[0]}} & in_data[0];
    for (int i = 1;i < ENTRIES;++i) begin
      out_data  = out_data | ({DATA_WIDTH{select[i]}} & in_data[i]);
    end
    return out_data;
  endfunction
endmodule

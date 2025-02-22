module qdrc_infrastructure(
    /* general signals */
    clk0,
    clk180,
    clk270,
    reset0,
    reset180,
    reset270,
    /* external signals */
    qdr_d,
    qdr_q,
    qdr_sa,
    qdr_w_n,
    qdr_r_n,
    qdr_dll_off_n,
    qdr_bw_n,
    //qdr_cq,
    //qdr_cq_n,
    qdr_k,
    qdr_k_n,
    //qdr_qvld,
    /* phy->external signals */
    qdr_d_rise,
    qdr_d_fall,
    qdr_q_rise,
    qdr_q_fall,
    qdr_bw_n_rise,
    qdr_bw_n_fall,
    qdr_sa_buf,
    qdr_w_n_buf,
    qdr_r_n_buf,
    qdr_dll_off_n_buf,
    //qdr_cq_buf,
    //qdr_cq_n_buf,
    //qdr_qvld_buf,

    /* phy training signals */
    dly_clk,
    dly_rst,
    dly_en_i,
    dly_en_o,
    dly_inc_dec,
    dly_cntrs
  );

  parameter DATA_WIDTH     = 36;
  parameter BW_WIDTH       = 4;
  parameter ADDR_WIDTH     = 21;
  parameter CLK_FREQ       = 200;
  parameter ODELAY_TAPS    = 0;
  parameter IDELAY_TAPS    = 0;

  localparam DLY_CLK_FREQ  = 200.0;

  input clk0,   clk180,   clk270;
  input reset0, reset180, reset270;

  output [DATA_WIDTH - 1:0] qdr_d;
  output   [BW_WIDTH - 1:0] qdr_bw_n;
  input  [DATA_WIDTH - 1:0] qdr_q;
  output [ADDR_WIDTH - 1:0] qdr_sa;
  output qdr_w_n;
  output qdr_r_n;
  output qdr_dll_off_n;
  output qdr_k, qdr_k_n;
  //input  qdr_cq, qdr_cq_n;
  //input  qdr_qvld;
  
  input  [DATA_WIDTH - 1:0] qdr_d_rise;
  input  [DATA_WIDTH - 1:0] qdr_d_fall;
  output [DATA_WIDTH - 1:0] qdr_q_rise;
  output [DATA_WIDTH - 1:0] qdr_q_fall;
  input    [BW_WIDTH - 1:0] qdr_bw_n_rise;
  input    [BW_WIDTH - 1:0] qdr_bw_n_fall;
  input  [ADDR_WIDTH - 1:0] qdr_sa_buf;
  input  qdr_w_n_buf, qdr_r_n_buf;
  input  qdr_dll_off_n_buf;
  //output qdr_cq_buf, qdr_cq_n_buf;
  //output qdr_qvld_buf;

  input         dly_clk;
  input         dly_rst;
  input  [35:0] dly_en_i;
  input  [36:0] dly_en_o;
  input         dly_inc_dec;

  output [5*(36+35)-1:0] dly_cntrs;

  /******************* QDR_K and QDR_K_N ********************
   * The clock is generated by an ODDR. This is done
   * to so the latency introduced by the ODDR on the data
   * line is introduced into the clock generation.
   * The clock uses clk0 while all other signals use clk270.
   */

  reg [35:0] counter [4:0];

  wire qdr_k_i,qdr_k_n_i;

  ODDR #(
    .DDR_CLK_EDGE ("SAME_EDGE"),
    .INIT         (1'b1),
    .SRTYPE       ("SYNC")
  ) ODDR_qdr_k (
    .Q  (qdr_k_i),
    .C  (clk0),
    .CE (1'b1),
    .D1 (1'b1), //Rising Edge
    .D2 (1'b0), //Falling Edge
    .R  (1'b0),
    .S  (1'b0)
  );

  IODELAYE1 #(
    .DELAY_SRC        ("O"),
    .ODELAY_TYPE      ("VARIABLE"),
    .ODELAY_VALUE     (ODELAY_TAPS),
    .REFCLK_FREQUENCY (DLY_CLK_FREQ),
    .SIGNAL_PATTERN   ("CLOCK"),
    .HIGH_PERFORMANCE_MODE ("TRUE")
  ) IODELAY_qdr_k (
    .C        (dly_clk),
    .CE       (dly_en_o[36]),
    .DATAIN   (1'b0),
    .IDATAIN  (),
    .INC      (dly_inc_dec),
    .ODATAIN  (qdr_k_i),
    .RST      (dly_rst),
    .T        (1'b0),
    .DATAOUT  (qdr_k),
	 .CNTVALUEOUT(dly_cntrs[4:0])
  );

  /* same as qdr_k -> just inverted */
  ODDR #(
    .DDR_CLK_EDGE ("SAME_EDGE"),
    .INIT         (1'b1),
    .SRTYPE       ("SYNC")
  ) ODDR_qdr_k_n (
    .Q  (qdr_k_n_i),
    .C  (clk0),
    .CE (1'b1),
    .D1 (1'b0), //Rising Edge
    .D2 (1'b1), //Falling Edge
    .R  (1'b0),
    .S  (1'b0)
  );

  IODELAYE1 #(
    .DELAY_SRC        ("O"),
    .ODELAY_TYPE      ("VARIABLE"),
    .ODELAY_VALUE     (ODELAY_TAPS),
    .REFCLK_FREQUENCY (DLY_CLK_FREQ),
    .SIGNAL_PATTERN   ("CLOCK"),
    .HIGH_PERFORMANCE_MODE ("TRUE")
  ) IODELAY_qdr_k_n (
    .C       (dly_clk),
    .CE      (dly_en_o[36]),
    .DATAIN  (1'b0),
    .IDATAIN (),
    .INC     (dly_inc_dec),
    .ODATAIN (qdr_k_n_i),
    .RST     (dly_rst),
    .T       (1'b0),
    .DATAOUT (qdr_k_n),
	 .CNTVALUEOUT(dly_cntrs[9:5])
  );

  /******************* SDR Control Signals ********************
   *
   */

  reg [ADDR_WIDTH - 1:0] qdr_sa_reg,qdr_sa_regR;
  reg qdr_w_n_reg,qdr_w_n_regR;
  reg qdr_r_n_reg,qdr_r_n_regR;
  wire qdr_r_n_delayed;

  /* This signals are all sliced so use the register in the slice */

  reg [ADDR_WIDTH - 1:0] qdr_sa_reg0;
  reg qdr_w_n_reg0;
  reg qdr_r_n_reg0;

  always @(posedge clk0) begin 
    qdr_sa_regR        <= qdr_sa_buf;
    qdr_w_n_regR       <= qdr_w_n_buf;
    qdr_r_n_regR       <= qdr_r_n_buf;
    qdr_sa_reg        <= qdr_sa_regR;
    qdr_w_n_reg       <= qdr_w_n_regR;
    qdr_r_n_reg       <= qdr_r_n_regR;
    qdr_dll_off_n_reg <= qdr_dll_off_n_buf;
    qdr_dll_off_n_iob <= qdr_dll_off_n_reg;
  end

  always @(posedge clk180) begin 
  /* Add delay to ease timing */
    qdr_sa_reg0  <= qdr_sa_reg;
    qdr_w_n_reg0 <= qdr_w_n_reg;
    qdr_r_n_reg0 <= qdr_r_n_reg;
    qdr_sa_iob   <= qdr_sa_reg0;
    qdr_w_n_iob  <= qdr_w_n_reg0;
    qdr_r_n_iob  <= qdr_r_n_reg0;
  end

  reg [ADDR_WIDTH - 1:0] qdr_sa_iob;
  reg qdr_w_n_iob;
  reg qdr_r_n_iob;
  reg qdr_dll_off_n_iob;
  reg qdr_dll_off_n_reg;
  //synthesis attribute IOB of qdr_sa_iob        is "TRUE"
  //synthesis attribute IOB of qdr_w_n_iob       is "TRUE"
  //synthesis attribute IOB of qdr_r_n_iob       is "TRUE"
  //synthesis attribute IOB of qdr_dll_off_n_iob is "TRUE"

  OBUF #(
    .IOSTANDARD ("HSTL_I")
  ) OBUF_addr[ADDR_WIDTH - 1:0]  
  (
    .I (qdr_sa_iob),
    .O (qdr_sa)
  );

  OBUF #(
    .IOSTANDARD ("HSTL_I")
  ) OBUF_w_n(
    .I (qdr_w_n_iob),
    .O (qdr_w_n)
  );

  OBUF #(
    .IOSTANDARD ("HSTL_I")
  ) OBUF_r_n(
    .I (qdr_r_n_iob),
    .O (qdr_r_n)
  );

  OBUF #(
    .IOSTANDARD ("HSTL_I")
  ) OBUF_dll_off_n(
    .I (qdr_dll_off_n_iob),
    .O (qdr_dll_off_n)
  );


  /******************* DDR Data Outputs ********************
   *
   */

  reg [DATA_WIDTH - 1:0] qdr_d_rise_reg0,qdr_d_rise_reg0R;
  reg [DATA_WIDTH - 1:0] qdr_d_fall_reg0,qdr_d_fall_reg0R;
  reg   [BW_WIDTH - 1:0] qdr_bw_n_rise_reg0;
  reg   [BW_WIDTH - 1:0] qdr_bw_n_fall_reg0;

  always @(posedge clk0) begin
  /* Delay the write data by one cycle (qdr protocol,
   * requires datat to lag control*/
    qdr_d_rise_reg0R    <= qdr_d_rise;
    qdr_d_fall_reg0R    <= qdr_d_fall;
    qdr_d_rise_reg0     <= qdr_d_rise_reg0R;
    qdr_d_fall_reg0     <= qdr_d_fall_reg0R;
    qdr_bw_n_rise_reg0  <= qdr_bw_n_rise;
    qdr_bw_n_fall_reg0  <= qdr_bw_n_fall;
  end

  reg [DATA_WIDTH - 1:0] qdr_d_rise_reg1;
  reg [DATA_WIDTH - 1:0] qdr_d_fall_reg1;
  reg   [BW_WIDTH - 1:0] qdr_bw_n_rise_reg1;
  reg   [BW_WIDTH - 1:0] qdr_bw_n_fall_reg1;

  // Stop XST from pipelining all this into a single shift register!
  //synthesis attribute SHREG_EXTRACT of qdr_d_rise_reg0 is no
  //synthesis attribute SHREG_EXTRACT of qdr_d_fall_reg0 is no
  //synthesis attribute SHREG_EXTRACT of qdr_sa_reg0     is no
  //synthesis attribute SHREG_EXTRACT of qdr_r_n_reg0    is no
  //synthesis attribute SHREG_EXTRACT of qdr_w_n_reg0    is no
  //synthesis attribute SHREG_EXTRACT of qdr_d_rise_reg1 is no
  //synthesis attribute SHREG_EXTRACT of qdr_d_fall_reg1 is no
  //synthesis attribute SHREG_EXTRACT of qdr_d_rise_reg0R is no
  //synthesis attribute SHREG_EXTRACT of qdr_d_fall_reg0R is no


  always @(posedge clk0) begin
  /* Delay to match the extra cycle on control lines 
   * due to extra iob delay route*/
    qdr_d_rise_reg1     <= qdr_d_rise_reg0;
    qdr_d_fall_reg1     <= qdr_d_fall_reg0;
    qdr_bw_n_rise_reg1  <= qdr_bw_n_rise_reg0;
    qdr_bw_n_fall_reg1  <= qdr_bw_n_fall_reg0;
  end


  reg [DATA_WIDTH - 1:0] qdr_d_rise_reg;
  reg [DATA_WIDTH - 1:0] qdr_d_fall_reg;
  reg   [BW_WIDTH - 1:0] qdr_bw_n_rise_reg;
  reg   [BW_WIDTH - 1:0] qdr_bw_n_fall_reg;

  always @(posedge clk270) begin
  /* Sample DDR signals onto clk270 domain.
   * The 270 clock is used to let the data lead the clock by
   * 90 degrees behind the clock. The signals are registered
   * to ease timing requirements.
   */
    qdr_d_rise_reg     <= qdr_d_rise_reg1;
    qdr_d_fall_reg     <= qdr_d_fall_reg1;
    qdr_bw_n_rise_reg  <= qdr_bw_n_rise_reg1;
    qdr_bw_n_fall_reg  <= qdr_bw_n_fall_reg1;
  end
  
  wire [DATA_WIDTH - 1:0] qdr_d_obuf,qdr_d_obuf_i;
  OBUF #(
    .IOSTANDARD ("HSTL_I")
  ) obuf_qdr_d [DATA_WIDTH - 1:0] (
    .O (qdr_d),
    .I (qdr_d_obuf)
  );

  IODELAYE1 #(
    .DELAY_SRC        ("O"),
    .ODELAY_TYPE      ("VARIABLE"),
    .ODELAY_VALUE     (ODELAY_TAPS),
    .REFCLK_FREQUENCY (DLY_CLK_FREQ),
    .SIGNAL_PATTERN   ("DATA"),
    .HIGH_PERFORMANCE_MODE ("TRUE")
  ) IODELAY_qdr_d [DATA_WIDTH - 1:0] (
    .C       (dly_clk),
    .CE      (dly_en_o[DATA_WIDTH-1:0]),
    .DATAIN  (1'b0),
    .IDATAIN (),
    .INC     (dly_inc_dec),
    .ODATAIN (qdr_d_obuf_i),
    .RST     (dly_rst),
    .T       (1'b0),
    .DATAOUT (qdr_d_obuf),
	 .CNTVALUEOUT()
  );

  ODDR #(
    .DDR_CLK_EDGE ("SAME_EDGE"),
    .INIT         (1'b1),
    .SRTYPE       ("SYNC")
  ) ODDR_qdr_d [DATA_WIDTH - 1:0] (
    .Q  (qdr_d_obuf_i),
    .C  (clk270),
    .CE (1'b1),
    .D1 (qdr_d_rise_reg), //Rising Edge
    .D2 (qdr_d_fall_reg), //Falling Edge
    .R  (1'b0),
    .S  (1'b0)
  );

/*
  ODDR #(
    .DDR_CLK_EDGE ("SAME_EDGE"),
    .INIT         (1'b1),
    .SRTYPE       ("SYNC")
  ) ODDR_qdr_bw_n [BW_WIDTH - 1:0] (
    .Q  (qdr_bw_n),
    .C  (clk270),
    .CE (1'b1),
    .D1 (qdr_bw_n_rise_reg), //Rising Edge
    .D2 (qdr_bw_n_fall_reg), //Falling Edge
    .R  (1'b0),
    .S  (1'b0)
  );
*/

  assign qdr_bw_n = {BW_WIDTH{1'b0}};


  /******************* DDR Data Inputs ********************
   * IODELAY for training
   */
 
  wire [DATA_WIDTH - 1:0] qdr_q_ibuf;
  wire [DATA_WIDTH - 1:0] qdr_q_iodelay;

  IBUF #(
    .IOSTANDARD ("HSTL_I_DCI")
  ) ibuf_qdr_q [DATA_WIDTH - 1:0](
    .I (qdr_q),
    .O (qdr_q_ibuf)
  );

  IODELAYE1 #(
    .DELAY_SRC        ("I"),
    .IDELAY_TYPE      ("VARIABLE"),
    .IDELAY_VALUE     (IDELAY_TAPS),
    .REFCLK_FREQUENCY (DLY_CLK_FREQ),
    .HIGH_PERFORMANCE_MODE ("TRUE")
  ) IODELAY_qdr_q [DATA_WIDTH - 1:0] (
    .C           (dly_clk),
    .CE          (dly_en_i[DATA_WIDTH-1:0]),
    .DATAIN      (1'b0),
    .IDATAIN     (qdr_q_ibuf),
    .INC         (dly_inc_dec),
    .ODATAIN     (),
    .RST         (dly_rst),
    .T           (1'b0),
    .DATAOUT     (qdr_q_iodelay[DATA_WIDTH - 1:0]),
	 .CNTVALUEOUT ()
  );

  wire [DATA_WIDTH - 1:0] qdr_q_rise_int;
  wire [DATA_WIDTH - 1:0] qdr_q_fall_int;

  //wire qdr_cq_bufg;

  IDDR #(
    .DDR_CLK_EDGE ("SAME_EDGE_PIPELINED"),
    .INIT_Q1 (1'b0),
    .INIT_Q2 (1'b0),
    .SRTYPE ("SYNC")
  ) IDDR_qdr_q [DATA_WIDTH - 1:0] (
    .C  (clk180),
    .CE (1'b1),
    .D  (qdr_q_iodelay),
    .R  (1'b0),
    .S  (1'b0),
    .Q1 (qdr_q_rise_int),
    .Q2 (qdr_q_fall_int)
  );

  reg [17:0] qdr_q_rise_intR_low , qdr_q_rise_intRR_low , qdr_q_rise_intRRR_low ;
  reg [17:0] qdr_q_rise_intR_high, qdr_q_rise_intRR_high, qdr_q_rise_intRRR_high;
  reg [17:0] qdr_q_fall_intR_low , qdr_q_fall_intRR_low , qdr_q_fall_intRRR_low ;
  reg [17:0] qdr_q_fall_intR_high, qdr_q_fall_intRR_high, qdr_q_fall_intRRR_high;

  always @(posedge clk180) begin
    qdr_q_rise_intR_high   <= qdr_q_rise_int [35:18];
    qdr_q_fall_intR_high   <= qdr_q_fall_int [35:18];
    qdr_q_rise_intRR_high  <= qdr_q_rise_intR_high;
    qdr_q_fall_intRR_high  <= qdr_q_fall_intR_high;
    qdr_q_rise_intRRR_high <= qdr_q_rise_intRR_high;
    qdr_q_fall_intRRR_high <= qdr_q_fall_intRR_high;
    qdr_q_rise_intR_low    <= qdr_q_rise_int  [17:0];
    qdr_q_fall_intR_low    <= qdr_q_fall_int  [17:0];
    qdr_q_rise_intRR_low   <= qdr_q_rise_intR_low;
    qdr_q_fall_intRR_low   <= qdr_q_fall_intR_low;
    qdr_q_rise_intRRR_low  <= qdr_q_rise_intRR_low;
    qdr_q_fall_intRRR_low  <= qdr_q_fall_intRR_low;
  end

  assign qdr_q_rise = {qdr_q_rise_intRRR_high, qdr_q_rise_intRRR_low};
  assign qdr_q_fall = {qdr_q_fall_intRRR_high, qdr_q_fall_intRRR_low};

  // Stop XST to chuck all this pipelining into a single shift register!
  //synthesis attribute SHREG_EXTRACT of qdr_q_rise_intR_low     is no
  //synthesis attribute SHREG_EXTRACT of qdr_q_fall_intR_low     is no
  //synthesis attribute SHREG_EXTRACT of qdr_q_rise_intRR_low    is no
  //synthesis attribute SHREG_EXTRACT of qdr_q_fall_intRR_low    is no
  //synthesis attribute SHREG_EXTRACT of qdr_q_rise_intRRR_low   is no
  //synthesis attribute SHREG_EXTRACT of qdr_q_fall_intRRR_low   is no
  //synthesis attribute SHREG_EXTRACT of qdr_q_rise_intR_high    is no
  //synthesis attribute SHREG_EXTRACT of qdr_q_fall_intR_high    is no
  //synthesis attribute SHREG_EXTRACT of qdr_q_rise_intRR_high   is no
  //synthesis attribute SHREG_EXTRACT of qdr_q_fall_intRR_high   is no
  //synthesis attribute SHREG_EXTRACT of qdr_q_rise_intRRR_high  is no
  //synthesis attribute SHREG_EXTRACT of qdr_q_fall_intRRR_high  is no

  //synthesis attribute IOB of qdr_q_rise_int is "TRUE"
  //synthesis attribute IOB of qdr_q_fall_int is "TRUE"


  
  //===========================================================================
  // Chipscope modules used to debug the controller
  //===========================================================================
  /*wire [35:0] ctrl0;
  wire [31:0] trig0,trig1,trig2,trig3,trig4,trig5,trig6,trig7,trig8,trig9,trig10,trig11,trig12,trig13,trig14,trig15; 

  chipscope_icon chipscope_icon_inst(
    .CONTROL0    (ctrl0)
  );  

  chipscope_ila chipscope_ila_inst(
    .CONTROL   (ctrl0),
    .CLK       (clk0),
    .TRIG0     (trig0),
    .TRIG1     (trig1),
    .TRIG2     (trig2),
    .TRIG3     (trig3),
    .TRIG4     (trig4),
    .TRIG5     (trig5),
    .TRIG6     (trig6),
    .TRIG7     (trig7),
    .TRIG8     (trig8),
    .TRIG9     (trig9),
    .TRIG10    (trig10),
    .TRIG11    (trig11),
    .TRIG12    (trig12),
    .TRIG13    (trig13),
    .TRIG14    (trig14),
    .TRIG15    (trig15)
  ); 

  // 1 -> 31
  assign trig0  = {qdr_r_n_buf, qdr_r_n_iob};
  // 32 -> 63
  assign trig1  = {qdr_d_rise[31:0]};
  // 64 -> 95
  assign trig2  = {qdr_d_fall[31:0]};
  // 96 -> 127
  assign trig3  = {qdr_q_rise[31:0]};
  assign trig4  = {qdr_q_fall[31:0]};
  assign trig5  = {qdr_sa_buf};
  assign trig6  = {dly_en_i[31:0]};
  assign trig7  = {dly_en_o[31:0]};
  assign trig8  = {dly_rst, dly_inc_dec};
  assign trig9  = {dly_cntrs[31:0]};
  assign trig10 = {32'h0};
  assign trig11 = {32'h0};
  assign trig12 = {32'h0};
  assign trig13 = {32'h0};
  assign trig14 = {32'h0};
  assign trig15 = {32'h0};
*/
// moo attribute HU_SET of qdr_w_n_reg  is SET_qdr_w_n
// moo attribute HU_SET of qdr_w_n_reg0 is SET_qdr_w_n
// moo attribute RLOC   of qdr_w_n_reg  is X0Y0
// moo attribute RLOC   of qdr_w_n_reg0 is X1Y0
// moo attribute HU_SET of qdr_r_n_reg  is SET_qdr_r_n
// moo attribute HU_SET of qdr_r_n_reg0 is SET_qdr_r_n
// moo attribute RLOC   of qdr_r_n_reg  is X0Y0
// moo attribute RLOC   of qdr_r_n_reg0 is X1Y0
// moo attribute HU_SET of qdr_sa_reg[0]  is SET_qdr_sa0
// moo attribute HU_SET of qdr_sa_reg0[0] is SET_qdr_sa0
// moo attribute RLOC   of qdr_sa_reg[0]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[0] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[1]  is SET_qdr_sa1
// moo attribute HU_SET of qdr_sa_reg0[1] is SET_qdr_sa1
// moo attribute RLOC   of qdr_sa_reg[1]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[1] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[2]  is SET_qdr_sa2
// moo attribute HU_SET of qdr_sa_reg0[2] is SET_qdr_sa2
// moo attribute RLOC   of qdr_sa_reg[2]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[2] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[3]  is SET_qdr_sa3
// moo attribute HU_SET of qdr_sa_reg0[3] is SET_qdr_sa3
// moo attribute RLOC   of qdr_sa_reg[3]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[3] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[4]  is SET_qdr_sa4
// moo attribute HU_SET of qdr_sa_reg0[4] is SET_qdr_sa4
// moo attribute RLOC   of qdr_sa_reg[4]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[4] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[5]  is SET_qdr_sa5
// moo attribute HU_SET of qdr_sa_reg0[5] is SET_qdr_sa5
// moo attribute RLOC   of qdr_sa_reg[5]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[5] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[6]  is SET_qdr_sa6
// moo attribute HU_SET of qdr_sa_reg0[6] is SET_qdr_sa6
// moo attribute RLOC   of qdr_sa_reg[6]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[6] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[7]  is SET_qdr_sa7
// moo attribute HU_SET of qdr_sa_reg0[7] is SET_qdr_sa7
// moo attribute RLOC   of qdr_sa_reg[7]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[7] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[8]  is SET_qdr_sa8
// moo attribute HU_SET of qdr_sa_reg0[8] is SET_qdr_sa8
// moo attribute RLOC   of qdr_sa_reg[8]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[8] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[9]  is SET_qdr_sa9
// moo attribute HU_SET of qdr_sa_reg0[9] is SET_qdr_sa9
// moo attribute RLOC   of qdr_sa_reg[9]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[9] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[10]  is SET_qdr_sa10
// moo attribute HU_SET of qdr_sa_reg0[10] is SET_qdr_sa10
// moo attribute RLOC   of qdr_sa_reg[10]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[10] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[11]  is SET_qdr_sa11
// moo attribute HU_SET of qdr_sa_reg0[11] is SET_qdr_sa11
// moo attribute RLOC   of qdr_sa_reg[11]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[11] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[12]  is SET_qdr_sa12
// moo attribute HU_SET of qdr_sa_reg0[12] is SET_qdr_sa12
// moo attribute RLOC   of qdr_sa_reg[12]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[12] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[13]  is SET_qdr_sa13
// moo attribute HU_SET of qdr_sa_reg0[13] is SET_qdr_sa13
// moo attribute RLOC   of qdr_sa_reg[13]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[13] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[14]  is SET_qdr_sa14
// moo attribute HU_SET of qdr_sa_reg0[14] is SET_qdr_sa14
// moo attribute RLOC   of qdr_sa_reg[14]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[14] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[15]  is SET_qdr_sa15
// moo attribute HU_SET of qdr_sa_reg0[15] is SET_qdr_sa15
// moo attribute RLOC   of qdr_sa_reg[15]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[15] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[16]  is SET_qdr_sa16
// moo attribute HU_SET of qdr_sa_reg0[16] is SET_qdr_sa16
// moo attribute RLOC   of qdr_sa_reg[16]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[16] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[17]  is SET_qdr_sa17
// moo attribute HU_SET of qdr_sa_reg0[17] is SET_qdr_sa17
// moo attribute RLOC   of qdr_sa_reg[17]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[17] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[18]  is SET_qdr_sa18
// moo attribute HU_SET of qdr_sa_reg0[18] is SET_qdr_sa18
// moo attribute RLOC   of qdr_sa_reg[18]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[18] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[19]  is SET_qdr_sa19
// moo attribute HU_SET of qdr_sa_reg0[19] is SET_qdr_sa19
// moo attribute RLOC   of qdr_sa_reg[19]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[19] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[20]  is SET_qdr_sa20
// moo attribute HU_SET of qdr_sa_reg0[20] is SET_qdr_sa20
// moo attribute RLOC   of qdr_sa_reg[20]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[20] is X1Y0


endmodule

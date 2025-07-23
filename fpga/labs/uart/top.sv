`include "config.svh"

module top
# (
    parameter clk_mhz    = 50,
              w_key      = 4,
              w_sw       = 8,
              w_led      = 8,
              w_digit    = 8,
              w_gpio     = 100,
    parameter BAUD_RATE  = 115200,
    parameter FIFO_EA    = 4,
    parameter BYTE_WIDTH = 1,
    parameter SYMB_START = "<",
    parameter SYMB_DELIM = "|",
    parameter SYMB_END   = ">",
    parameter expWidth   = 8,
    parameter sigWidth   = 24,
    parameter FLOAT_SIZE = expWidth + sigWidth,
    parameter VAR_WIDTH  = FLOAT_SIZE / (BYTE_WIDTH * 8),
    parameter VAR_LENG   = FLOAT_SIZE / VAR_WIDTH
)
(
    input                        clk,
    input                        slow_clk,
    input                        rst,

    // Keys, switches, LEDs

    input        [w_key   - 1:0] key,
    input        [w_sw    - 1:0] sw,
    output logic [w_led   - 1:0] led,

    // A dynamic seven-segment display

    output logic [          7:0] abcdefgh,
    output logic [w_digit - 1:0] digit,

    // VGA

    output logic                 vsync,
    output logic                 hsync,
    output logic [          3:0] red,
    output logic [          3:0] green,
    output logic [          3:0] blue,

    input                        uart_rx,
    output                       uart_tx,

    input                        mic_ready,
    input        [         23:0] mic,
    output       [         15:0] sound,

    // General-purpose Input/Output

    inout        [w_gpio  - 1:0] gpio
);

    //------------------------------------------------------------------------

    assign led      = '0;
    // assign abcdefgh = '0;
    // assign digit    = '0;
       assign vsync    = '0;
       assign hsync    = '0;
       assign red      = '0;
       assign green    = '0;
       assign blue     = '0;
       assign sound    = '0;
    //    assign uart_tx  = '1;

    //------------------------------------------------------------------------

    // FSM 
    typedef enum bit [2:0] 
    {
        idle      = 3'd0,
        read_op   = 3'd1, 
        read_a    = 3'd2,
        read_b    = 3'd3,
        calculate = 3'd4,
        send_res  = 3'd5
    }
    fsm_state; 

    fsm_state state, next_state;
    logic fsm_en; 

    always_ff @ ( posedge clk or posedge rst)
    begin
        if ( rst )
            state <= read_op;
        else if ( fsm_en )
            state <= next_state;
    end


    // UART 
    logic [15:0             ] cnt;
    logic                     rx_ready;
    logic                     rx_valid;
    logic [ 7:0]              rx_data;
    logic                     rx_overflow;
    logic                     rx_symbol;
    logic                     tx_ready;
    logic                     tx_valid;
    logic [8*BYTE_WIDTH-1:0 ] tx_data;
    logic [  BYTE_WIDTH-1:0 ] tx_keep;
    logic                     tx_last;

    logic                     read_cnt; // TODO: calculate real size (for 64bits it works and it's okay i think)

    // FPU
    logic [VAR_WIDTH:0][VAR_LENG:0]   fpu_a;
    logic [VAR_WIDTH:0][VAR_LENG:0]   fpu_b;
    logic [VAR_WIDTH:0][VAR_LENG:0]   fpu_res;

    logic [  FLOAT_SIZE:0           ] fpu_a_flatten;
    logic [  FLOAT_SIZE:0           ] fpu_b_flatten;
    logic [  FLOAT_SIZE:0           ] fpu_res_flatten;

    logic [  BYTE_WIDTH:0           ] fpu_op;
    logic                             fpu_valid;
    logic                             fpu_ready;
    logic [  7:0                    ] fpu_flags;

    // Some test data to send
    assign tx_data = 'd31;

    // Uart receive
    uart_rx # (
        .BAUD_RATE  (BAUD_RATE  ),
        .FIFO_EA    (FIFO_EA    ))
    rx (
        .rstn       ( ~rst        ),
        .clk        ( clk         ),
        .i_uart_rx  ( uart_rx     ),
        .o_tready   ( tx_ready    ),
        .o_tvalid   ( rx_valid    ),
        .o_tdata    ( rx_data     ),
        .o_overflow ( rx_overflow )
    );

    // Uart send
    uart_tx # (
        .BAUD_RATE  ( BAUD_RATE  ),
        .FIFO_EA    ( FIFO_EA    ),
        .BYTE_WIDTH ( BYTE_WIDTH + 3 ),
        .STOP_BITS  ( 1          )
    ) tx (
        .rstn       ( ~rst      ),
        .clk        ( clk       ),
        .i_tready   ( tx_ready  ),
        .i_tvalid   ( rx_valid  ),
        .i_tdata    ( {"-", rx_data, "-\n"}),
        .i_tkeep    ( 4'('1)    ),
        .i_tlast    ( '1        ),
        .o_uart_tx  ( uart_tx   )
    );
    
    //------------------------------------------------------------------------
    // DEBUG MOMENT
    seven_segment_display
    # (
        .w_digit   ( w_digit ),
        .clk_mhz   ( clk_mhz ),
        .update_hz ( 4 ) // Looks like a sane default
    )
    (
        .clk ( clk ),
        .rst ( rst ),

        .number(cnt),
        .dots('0),
        .abcdefgh(abcdefgh),
        .digit(digit)
    );

    //------------------------------------------------------------------------

    always_ff @( posedge clk or posedge rst ) 
    begin
        if ( rst )
            cnt <= '0;
        else if (rx_valid & tx_ready)
            cnt <= cnt + 1'd1;
    end

    //------------------------------------------------------------------------

    // Read numbers

    always_ff @( posedge clk or posedge rst ) 
    begin
        if ( rst )
        begin
            fpu_a <= '0;
            fpu_b <= '0;
            fpu_op <= '0;
        end
        else if (rx_valid)
        begin
            if ( state == read_a)
            begin
              fpu_a[read_cnt] <= rx_data;
              read_cnt <= read_cnt + 1'd1;
            end
            else if ( state == read_b  )
            begin
              fpu_b[read_cnt] <= rx_data;
              read_cnt <= read_cnt + 1'd1;
            end
            else if ( state == read_op )
            begin
              fpu_op[read_cnt] <= rx_data;
              read_cnt <= read_cnt + 1'd1;
            end
        end
    end

    always_comb begin
    // for ( i = 0; i < VAR_WIDTH; i = i + 1)
    //     begin
        fpu_a_flatten    [ 7:0   ] <= fpu_a[0];
        fpu_a_flatten    [ 15:8  ] <= fpu_a[1];
        fpu_a_flatten    [ 15:8  ] <= fpu_a[2];
        fpu_a_flatten    [ 23:16 ] <= fpu_a[3];
        fpu_a_flatten    [ 31:24 ] <= fpu_a[4];

        fpu_b_flatten    [ 7:0   ] <= fpu_b[0];
        fpu_b_flatten    [ 15:8  ] <= fpu_b[1];
        fpu_b_flatten    [ 15:8  ] <= fpu_b[2];
        fpu_b_flatten    [ 23:16 ] <= fpu_b[3];
        fpu_b_flatten    [ 31:24 ] <= fpu_b[4];

        fpu_res_flatten  [ 7:0   ] <= fpu_res[0];
        fpu_res_flatten  [ 15:8  ] <= fpu_res[1];
        fpu_res_flatten  [ 15:8  ] <= fpu_res[2];
        fpu_res_flatten  [ 23:16 ] <= fpu_res[3];
        fpu_res_flatten  [ 31:24 ] <= fpu_res[4];

        // end
    end
    //------------------------------------------------------------------------
    // FPU
    fpu
    # (
        .expWidth   ( expWidth   ),
        .sigWidth   ( sigWidth   ),
        .FLOAT_SIZE ( FLOAT_SIZE ),
        .BYTE_WIDTH ( BYTE_WIDTH )
    ) (
        .a       ( fpu_a_flatten  ),
        .b       ( fpu_b_flatten  ),
        .op      ( fpu_op         ),

        .result  ( fpu_res   ),
        .flags   ( fpu_flags ),
        .valid_o ( fpu_valid ),

        .clk     ( clk            ),        // All these field needed only for division only
        .rst     ( rst            )
        // .ready   ( fpu_ready      )
    );

    //------------------------------------------------------------------------
    // FSM

    always_ff @( posedge clk or posedge rst )  begin
        case (state)
        idle:      if ( rx_data == SYMB_START ) next_state = read_op;
        read_op:   if ( rx_data == SYMB_DELIM ) next_state = read_a;
        read_a:    if ( rx_data == SYMB_DELIM ) next_state = read_b;
        read_b:    if ( rx_data == SYMB_END   ) next_state = calculate;
        calculate: if (     fpu_valid         ) next_state = send_res;
        send_res:  if (     rx_ready          ) next_state = idle;
        endcase
    end
    


endmodule

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
    parameter SYMB_START   = "<",
    parameter SYMB_DELIM   = "|",
    parameter SYMB_END     = ">"
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

    // assign led      = '0;
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

    // FPU
    logic [8*BYTE_WIDTH-1:0 ] fpu_a;
    logic [8*BYTE_WIDTH-1:0 ] fpu_b;
    logic [8*BYTE_WIDTH-1:0 ] fpu_res;
    logic [7:0 ] fpu_op;
    logic                     fpu_valid;
    logic                     fpu_ready;

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
        .STOP_BITS  ( 1          ))
    tx (
        .rstn       ( ~rst      ),
        .clk        ( clk       ),
        .i_tready   ( tx_ready  ),
        .i_tvalid   ( rx_valid ),
        .i_tdata    ( {"-", rx_data, "-\n"}),
        .i_tkeep    ( 4'('1)   ),
        .i_tlast    ( '1   ),
        .o_uart_tx  ( uart_tx   )
    );
    
    //------------------------------------------------------------------------

    

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

// 


    always_ff @( posedge clk or posedge rst ) 
    begin
        if ( rst )
            cnt <= '0;
        else if (rx_valid & tx_ready)
            cnt <= cnt + 1'd1;
    end

    // // Manipulate tx
    // assign tx_valid = tx_ready & sw[0];
    
    // // Manipulate rx
    // assign rx_ready = sw[1];
    
    // // Show info on leds
    // assign led[2:0] = cnt[7:5];
    // assign led[3]   = rx_overflow;


    // // rx fsm logic:
    // // Read op -> read a -> read b -> wait fpu to complete -> send res
    // always_comb 
    // begin
    //     next_state = state;




    //     case (state)
    //     idle:      if (rx_data == SYMB_START)
    //     read_op:   if (rx_data == SYMB_DELIM) next_state = read_a;
    //     read_a:    if (rx_data == SYMB_DELIM) next_state = read_b;
    //     read_b:    if (rx_data == SYMB_END)   next_state = calculate;
    //     calculate: if (     fpu_valid       ) next_state = send_res;
    //     send_res:  if (     rx_ready        ) next_state = idle;
    //     endcase

    // end
    


endmodule

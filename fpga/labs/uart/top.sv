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
    parameter FIFO_EA    = 2,
    parameter BYTE_WIDTH = 1
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

    logic  [15:0           ]  cnt;
    wire                      rx_ready;
    wire                      rx_valid;
    wire                      rx_data;
    wire                      rx_overflow;
    wire                      tx_ready;
    wire                      tx_valid;
    wire  [8*BYTE_WIDTH-1:0 ] tx_data;
    wire  [  BYTE_WIDTH-1:0 ] tx_keep;
    wire                      tx_last;

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
          .o_tready   ( rx_ready    ),
          .o_tvalid   ( rx_valid    ),
          .o_tdata    ( rx_data     ),
          .o_overflow ( rx_overflow    )
    );

    // Uart send
    uart_tx # (
        .BAUD_RATE  ( BAUD_RATE  ),
        .FIFO_EA    ( FIFO_EA    ),
        .BYTE_WIDTH ( BYTE_WIDTH ))
    tx (
        .rstn       ( ~rst      ),
        .clk        ( clk       ),
        .i_tready   ( tx_ready  ),
        .i_tvalid   ( tx_valid  ),
        .i_tdata    ( tx_data   ),
        .i_tkeep    ( tx_keep   ),
        .o_uart_tx  ( uart_tx   )
    );
    
    //------------------------------------------------------------------------


    always_ff @( posedge clk or posedge rst ) 
    begin
        if ( rst )
            cnt <= '0;
        else if (rx_valid)
            cnt <= cnt + 1'd1;
    end

    // Manipulate tx
    assign tx_valid = tx_ready & sw[0];
    
    // Manipulate rx
    assign rx_ready = sw[1];
    
    // Show info on leds
    assign led[2:0] = cnt[7:5];
    assign led[3]   = rx_overflow;
    


endmodule

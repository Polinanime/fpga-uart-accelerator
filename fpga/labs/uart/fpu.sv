module fpu
# (
    parameter expWidth   = 8,
    parameter sigWidth   = 24,
    parameter FLOAT_SIZE = 32,
    parameter BYTE_WIDTH = 1
)
(
    // input                    clk,
    // input                    rst,
    // input                    ready,
    input [ FLOAT_SIZE-1:0 ] a,
    input [ FLOAT_SIZE-1:0 ] b,
    input [ 8*BYTE_WIDTH-1:0 ] op,

    output [FLOAT_SIZE-1:0 ] result,
    output [7:0            ] flags,
    output                   valid_o    
);
    logic [ FLOAT_SIZE-1:0 ] result_add;
    logic [ FLOAT_SIZE-1:0 ] result_mul;
    logic [ FLOAT_SIZE-1:0 ] result_sub;
    logic [ FLOAT_SIZE-1:0 ] result_div;
    logic                    result_comp_gt;
    logic                    result_comp_lt;
    logic                    result_comp_eq;
    logic                    result_comp_un;



    logic        [7:0] flags_add;
    logic        [7:0] flags_mul;
    logic        [7:0] flags_sub;
    logic        [7:0] flags_comp;
    logic        [7:0] flags_div;


    assign result_add     = (a + b);
    // assign result_sub     = (a - b);
    // assign result_mul     = (a * b);
    // assign result_comp_gt = (a > b);
    // assign result_comp_lt = (a < b);
    // assign result_comp_eq = (a == b);




    // mulRecFN # (
    //     .expWidth ( expWidth ),
    //     .sigWidth ( sigWidth )
    // ) mul (
    //     .control        ( '0               ),  // (a*b)
    //     .a              ( a                ),
    //     .b              ( b                ),
    //     .roundingMode   ( `round_near_even ),
    //     .out            ( result_mul       ),
    //     .exceptionFlags ( flags_mul        )
    // );

    // addRecFN # (
    //     .expWidth ( expWidth ),
    //     .sigWidth ( sigWidth )
    // ) add (
    //     .control        ( '0               ),
    //     .subOp          ( '0               ),   // a+b
    //     .a              ( a                ),
    //     .b              ( b                ),
    //     .roundingMode   ( `round_near_even ),
    //     .out            ( result_add       ),
    //     .exceptionFlags ( flags_add        )
    // );

    addRecFN # (
        .expWidth ( expWidth ),
        .sigWidth ( sigWidth )
    ) sub (
        .control        ( '0               ),
        .subOp          ( '1               ),   // a-b
        .a              ( a                ),
        .b              ( b                ),
        .roundingMode   ( `round_near_even ),
        .out            ( result_sub       ),
        .exceptionFlags ( flags_sub        )
    );

    // compareRecFN # (
    //     .expWidth ( expWidth ),
    //     .sigWidth ( sigWidth )
    // ) copm (
    //     .a              ( a                ),
    //     .b              ( b                ),
    //     .lt             ( result_comp_lt   ),   // a<b
    //     .eq             ( result_comp_eq   ),   // a=b
    //     .gt             ( result_comp_rt   ),   // a>b
    //     .unordered      ( result_comp_un   ),   // a=NaN | b=NaN
    //     .exceptionFlags ( flags_comp       )
    // );


    // TODO: IMPLEMENT DIVISION 
    //
    // ivSqrtRecFN_small#(
    //     .expWidth ( expWidth ),
    //     .sigWidth ( sigWidth ),
    //     .options  (          )
    // ) div (
    //     .nReset         ( ~rst ),
    //     .clock          (  clk ),
    //     // .control  (          ), // Currently, the only valid value for the options parameter is zero
    //     .inReady        ( ready ),
    //     .inValid        ( valid ),
    //     input sqrtOp,
    //     input [(expWidth + sigWidth):0] a,
    //     input [(expWidth + sigWidth):0] b,
    //     input [2:0] roundingMode,
    //     output outValid,
    //     output sqrtOpOut,
    //     output [(expWidth + sigWidth):0] out,
    //     output [4:0] exceptionFlags
    // );



    always_comb begin
        result      = '0;
        flags       = '0;
        valid_o     = '0;

        case ( op )
        "*": 
        begin
            result   = result_mul;
            flags    = flags_mul;
            valid_o  = '1;
        end
        "+":
        begin
            result   = result_add;
            flags    = flags_add;
            valid_o  = '1;
        end
        "-":
        begin
            result   = result_sub;
            flags    = flags_sub;
            valid_o  = '1;
        end
        "/":
        begin
            result   = result_div;
            flags    = flags_div;
            valid_o  = '1;
        end
        ">":
        begin
            result   = result_comp_gt;
            flags    = flags_comp;
            valid_o  = '1;
        end
        "<":
        begin
            result   = result_comp_lt;
            flags    = flags_comp;
            valid_o  = '1;
        end
        "=":
        begin
            result   = result_comp_eq;
            flags    = flags_comp;
            valid_o  = '1;
        end
        endcase
    end

endmodule
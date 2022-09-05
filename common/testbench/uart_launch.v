//---------------------------------------------
// Purpose : a device launches serial data
//---------------------------------------------

module uart_launch (
    input   wire                    RESETn,
    input   wire                    CLK,
    input   wire    [128*8-1:0]     MSG,
    input   wire                    REQ,
    output  wire                    DONE,
    output  wire                    TXD
);

    reg    [7:0]          tx_shift_data;
    reg    [128*8-1:0]    reg_msg;
    reg                   reg_txd;
    reg                   reg_done;
    reg                   reg_start;

    integer               i;

    assign TXD  = reg_txd;
    assign DONE = reg_done;

    initial begin
        reg_txd   = 1'b1;
        reg_done  = 1'b0;
        reg_start = 1'b0;
    end

    always @(REQ) begin
        if (REQ) begin
            reg_msg  = MSG;
            reg_done = 1'b0;
            while (reg_msg[128*8-1:128*8-8] == 8'h0) begin
                reg_msg = reg_msg << 8;
            end
            $write("%t UART device sends: ", $time);
            while (!reg_msg[128*8-1:128*8-8] == 8'h0) begin
                tx_shift_data = reg_msg[128*8-1:128*8-8];
                $write("%s", tx_shift_data);
                @(posedge CLK);
                reg_txd = 1'b0;
                for (i = 0; i < 8; i = i + 1) begin
                    @(posedge CLK);
                    reg_txd = tx_shift_data[0];
                    tx_shift_data = tx_shift_data >> 1;
                end
                @(posedge CLK);
                reg_txd = 1'b1;
                reg_msg = reg_msg << 8;
            end
            reg_done = 1'b1;
        end
    end

endmodule
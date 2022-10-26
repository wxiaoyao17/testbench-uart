//---------------------------------------------
// Purpose : UART controller with APB interface & one clock
//---------------------------------------------

module apb_sync_uart (
    input  wire         pclk,
    input  wire         presetn,
    input  wire         psel,
    input  wire         penable,
    input  wire         pwrite,
    input  wire  [11:0] paddr,
    input  wire  [31:0] pwdata,
    output wire         pready,
    output wire         pslverr,
    output wire  [31:0] prdata,
    output wire         tx_int,
    output wire         rx_int,
    output wire         tx,
    input wire          rx
);

    `include "uart_const_pkg.v"

    localparam IDLE  = 4'h0;
    localparam START = 4'h1;
    localparam DATA0 = 4'h2;
    localparam DATA1 = 4'h3;
    localparam DATA2 = 4'h4;
    localparam DATA3 = 4'h5;
    localparam DATA4 = 4'h6;
    localparam DATA5 = 4'h7;
    localparam DATA6 = 4'h8;
    localparam DATA7 = 4'h9;
    localparam STOP  = 4'hA;

    reg  [3:0]  tx_state;
    reg  [3:0]  nxt_tx_state;
    reg  [3:0]  rx_state;
    reg  [3:0]  nxt_rx_state;
    reg  [3:0]  reg_ctrl;
    reg  [7:0]  reg_tx_buf;
    reg  [7:0]  reg_rx_buf;
    reg [19:0]  reg_baud;
    reg         reg_tx_int;
    reg         reg_rx_int;
    reg [31:0]  read_data;
    reg         baud_update;
    reg [19:0]  baud_cnt;
    reg  [7:0]  tx_shift_data;
    reg  [7:0]  rx_shift_data;
    reg         rx_buf_full;
    reg         tx_buf_full;
    reg         baud_tick;

    wire        write_enable;
    wire        read_enable;
    wire        ctrl_write;
    wire        tx_buf_write;
    wire        baud_write;
    wire        int_write;
    wire        baud_reload;
    wire        tx_valid;
    wire        rx_valid;
    wire        tx_buf_clear;
    wire        rx_buf_clear;
    wire        rx_buf_write;
    wire        tx_int_set;
    wire        rx_int_set;

    assign pslverr          = 1'b0;
    assign pready           = 1'b1;
    assign prdata           = (read_enable) ? read_data : {32{1'b0}};

    assign write_enable     = psel & ~penable & pwrite;
    assign read_enable      = psel & ~pwrite;

    assign ctrl_write       = write_enable & (paddr[11:2] == UART_CTRL_OFFSET[11:2]);
    assign tx_buf_write     = write_enable & (paddr[11:2] == UART_DATA_OFFSET[11:2]);
    assign baud_write       = write_enable & (paddr[11:2] == UART_BAUD_OFFSET[11:2]);
    assign int_write       = write_enable & (paddr[11:2] == UART_INT_OFFSET[11:2]);

    assign tx = (tx_state == START) ? 1'b0 :
                (tx_state == STOP)  ? 1'b1 :
                (tx_state == IDLE)  ? 1'b1 : tx_shift_data[0];

    //---------------------------------------------
    // Purpose : UART controller with APB interface & one clock
    //---------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            reg_ctrl <= UART_CTRL_RESET[3:0];
        end
        else if (ctrl_write) begin
            reg_ctrl <= pwdata[3:0];
        end
    end

    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            reg_tx_buf <= UART_DATA_RESET[7:0];
        end
        else if (tx_buf_write) begin
            reg_tx_buf <= pwdata[7:0];
        end
    end

    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            reg_baud <= UART_BAUD_RESET[19:0];
        end
        else if (baud_write) begin
            reg_baud <= pwdata[19:0];
        end
    end

    assign tx_int_set = reg_ctrl[2] & tx_buf_clear;
    
    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            reg_tx_int <= UART_INT_RESET[0];
        end
        else if ((int_write & pwdata[0]) | tx_int_set) begin
            reg_tx_int <= tx_int_set;
        end
    end

    assign rx_int_set = reg_ctrl[3] & rx_buf_write;

    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            reg_rx_int <= UART_INT_RESET[1];
        end
        else if ((int_write & pwdata[1]) | rx_int_set) begin
            reg_rx_int <= rx_int_set;
        end
    end

    always @(*) begin
        case (paddr[11:2])
            UART_CTRL_OFFSET[11:2]: begin
                read_data = {28'h0, reg_ctrl};
            end
            UART_STAT_OFFSET[11:2]: begin
                read_data = {30'h0, rx_buf_full, tx_buf_full};
            end
            UART_DATA_OFFSET[11:2]: begin
                read_data = {24'h0, reg_rx_buf};
            end
            UART_BAUD_OFFSET[11:2]: begin
                read_data = {12'h0, reg_baud};
            end
            UART_INT_OFFSET[11:2]: begin
                read_data = {30'h0, reg_rx_int, reg_tx_int};
            end
            default: begin
                read_data = 32'h0;
            end
        endcase
    end

    //---------------------------------------------
    // baud rate handling
    //---------------------------------------------

    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            baud_update <= 1'b0;
        end
        else begin
            baud_update <= baud_write;
        end
    end

    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            baud_tick <= 1'b0;
        end
        else begin
            baud_tick <= baud_reload;
        end
    end

    assign baud_reload = (reg_ctrl[1:0] != 2'b00) & (baud_cnt == 20'h0);

    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            baud_cnt <= 20'b0;
        end
        else if (baud_update | baud_reload) begin
            baud_cnt <= reg_baud;
        end
        else if (reg_ctrl[1:0] != 2'b00) begin
            baud_cnt <= baud_cnt - 20'h1;
        end
    end

    //---------------------------------------------
    // shift register
    //---------------------------------------------

    assign tx_shift = (nxt_tx_state != IDLE) & (nxt_tx_state != START) & (nxt_tx_state != STOP);
    assign rx_shift = (nxt_rx_state != IDLE) & (nxt_rx_state != START) & (nxt_rx_state != STOP);

    // tx shift register
    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            tx_shift_data <= 8'hFF;
        end
        else if (tx_state == START) begin
            tx_shift_data <= reg_tx_buf;
        end
        else if (tx_shift & baud_tick) begin
            tx_shift_data <= {1'b1, tx_shift_data[7:1]};
        end
    end

    // Clear buffer full status when data is load into shift register
    assign tx_buf_clear = (tx_state == START) & baud_tick;

    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            tx_buf_full <= 1'b0;
        end
        else if (tx_buf_write) begin
            tx_buf_full <= 1'b1;
        end
        else if (tx_buf_clear) begin
            tx_buf_full <= 1'b0;
        end
    end

    // rx shift register
    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            rx_shift_data <= 8'hFF;
        end
        else if (rx_shift & baud_tick) begin
            rx_shift_data <= {rx, rx_shift_data[7:1]};
        end
    end

    // rx buffer register
    assign rx_buf_write = (nxt_rx_state == STOP) & baud_tick;

    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            reg_rx_buf <= UART_DATA_RESET[7:0];
        end
        else if (rx_buf_write) begin
            reg_rx_buf <= rx_shift_data;
        end
    end

    assign rx_buf_clear = read_enable & penable & (paddr[11:2] == UART_DATA_OFFSET[11:2]);

    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            rx_buf_full <= 1'b0;
        end
        else if (rx_buf_write) begin
            rx_buf_full <= 1'b1;
        end
        else if (rx_buf_clear) begin
            rx_buf_full <= 1'b0;
        end
    end

    //---------------------------------------------
    // TX state machine control
    //---------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            tx_state <= 4'h0;
        end
        else begin
            tx_state <= nxt_tx_state;
        end
    end

    assign tx_valid = tx_buf_full & baud_tick & reg_ctrl[0];

  always @(*) begin
    nxt_tx_state = tx_state;
    case (tx_state)
        IDLE : begin
            nxt_tx_state = tx_valid ? START : IDLE;
        end
        START,DATA0,DATA1,DATA2,DATA3,DATA4,DATA5,DATA6,DATA7 : begin
            nxt_tx_state = tx_state + {3'h0, baud_tick};
        end
        STOP : begin
            if (baud_tick)
                nxt_tx_state = tx_valid ? START : IDLE;
        end
        default: nxt_tx_state = IDLE;
    endcase
  end

    //---------------------------------------------
    // RX state machine control
    //---------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (~presetn) begin
            rx_state <= 4'h0;
        end
        else begin
            rx_state <= nxt_rx_state;
        end
    end

    assign rx_valid = ~rx & baud_tick & reg_ctrl[1];

  always @(*) begin
    nxt_rx_state = rx_state;
    case (rx_state)
        IDLE : begin
            nxt_rx_state = rx_valid ? START : IDLE;
        end
        START,DATA0,DATA1,DATA2,DATA3,DATA4,DATA5,DATA6,DATA7 : begin
            nxt_rx_state = rx_state + {3'h0, baud_tick};
        end
        STOP : begin
            if (baud_tick)
                nxt_rx_state = rx_valid ? START : IDLE;
        end
        default: nxt_rx_state = IDLE;
    endcase
  end

  assign tx_int = reg_tx_int;
  assign rx_int = reg_rx_int;

endmodule

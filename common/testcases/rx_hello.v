reg [31:0] read_data;
reg [7:0] read_msg [0:128];
integer bytes_point,i;

initial begin
    bytes_point = 0;
    read_data = 32'h0;
    wait(reset);
    // config uart controller
    bus_write(UART_BAUD_OFFSET, 32'h4);
    bus_write(UART_CTRL_OFFSET, 32'hF);

    // uart device sends message
    fork
        device_send("hello world!\n");
        poll_data;
    join
    #300 $finish;
end

task poll_data;
    begin
        while (1) begin
            bus_read(UART_STAT_OFFSET,read_data);
            while(~read_data[1]) begin
                bus_read(UART_STAT_OFFSET,read_data);
            end
            bus_read(UART_DATA_OFFSET,read_msg[bytes_point]);
            if (read_msg[bytes_point] == 8'h0A) begin
                $write("%t UART controller captures: ", $time);
                for (i = 0; i <= bytes_point; i=i+1) begin
                    $write("%s", read_msg[i]);
                end
                $write("\n");
                disable poll_data;
            end
            bytes_point = bytes_point + 1;
        end
    end
endtask
//---------------------------------------------
// UART sends hello_world message to test tx function
//---------------------------------------------

initial begin
    wait(reset);
    bus_write(UART_BAUD_OFFSET, 32'h4);
    bus_write(UART_CTRL_OFFSET, 32'hF);
    #100;
    controller_send("hello world!\n");
    #100000 $finish;
end
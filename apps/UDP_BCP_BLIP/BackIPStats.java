import java.io.IOException;
import java.util.Date;

import net.tinyos.message.*;
import net.tinyos.packet.*;
import net.tinyos.util.*;
import org.apache.commons.cli.*;

public class BackIPStats implements MessageListener {

	private MoteIF moteIF;
	static int num_runs;
	static int tot_pkts;

	public BackIPStats(MoteIF moteIF) {
		this.moteIF = moteIF;
		this.moteIF.registerListener(new BackIPStatsMsg(), this);
	}

	public void send() {
		BackIPStatsMsg msg = new BackIPStatsMsg();

		try {
			moteIF.send(0, msg);
		}
		catch (IOException exception) {
			p("Error");
			System.err.println("Exception thrown when sending packets. Exiting.");
			System.err.println(exception);
		}
		p("Sent");
	}

	public void px(String data) {
		System.out.print(data);
	}
	public void p(String data) {
		System.out.println(data);
	}

	public static String leftPad(String s, int width) {
		String ret = s;
		while(ret.length() < width) {
			ret = " " + ret;
		}
		return ret;
	}

	public void messageReceived(int to, Message message) {
		BackIPStatsMsg msg = (BackIPStatsMsg)message;
		p(Short.toString(msg.get_sender()) + ":" +
				Long.toString(msg.get_ctr()) + ":" +
				Long.toString(msg.get_recv_time()) + ":" +
				Long.toString(msg.get_delay()));
		//p(msg.toString());
	}

	public static void main(String[] args) throws Exception {
		String source = null;

		CommandLineParser parser = new BasicParser();
		Options options = new Options();
		Option comm   = OptionBuilder.withArgName( "comm" )
			.hasArg()
			.withDescription(  "use given source for serial forwarder" )
			.create( "comm" );

		// automatically generate the help statement
		HelpFormatter formatter = new HelpFormatter();

		options.addOption(comm);
		CommandLine line;

		try {
			// parse the command line arguments
			line = parser.parse( options, args );

			if(line.hasOption("comm")) {
				source = line.getOptionValue("comm");
			}
			PhoenixSource phoenix;

			if (source == null) {
				phoenix = BuildSource.makePhoenix(PrintStreamMessenger.err);
			}
			else {
				phoenix = BuildSource.makePhoenix(source, PrintStreamMessenger.err);
			}

			MoteIF mif = new MoteIF(phoenix);
			BackIPStats serial = new BackIPStats(mif);
			serial.send();

		}
		catch( Exception exp ) {
			// oops, something went wrong
			System.err.println( "Connect failed.  Reason: " + exp.getMessage() );
		}
	}
}

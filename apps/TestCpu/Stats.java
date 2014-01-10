import java.io.IOException;

import net.tinyos.message.*;
import net.tinyos.packet.*;
import net.tinyos.util.*;
import org.apache.commons.cli.*;

public class Stats implements MessageListener {

	private MoteIF moteIF;
	static int num_runs;
	static int tot_pkts;

	public Stats(MoteIF moteIF) {
		this.moteIF = moteIF;
		this.moteIF.registerListener(new StatsMsg(), this);
	}

	public void px(String data) {
		System.out.print(data);
	}
	public void p(String data) {
		System.out.println(data);
	}

	public void messageReceived(int to, Message message) {
		StatsMsg msg = (StatsMsg)message;
		p("Start: " +msg.get_st());
		p("End  : " +msg.get_end());
		p("Diff : " +msg.get_diff());
		p("Ctr  : " +msg.get_ctr());
	}

	public static void main(String[] args) throws Exception {
		String source = null;

		CommandLineParser parser = new BasicParser();
		Options options = new Options();
		Option comm   = OptionBuilder.withArgName( "comm" )
			.hasArg()
			.withDescription(  "use given source for serial forwarder" )
			.create( "comm" );
		Option cmd   = OptionBuilder.withArgName( "cmd" )
			.hasArg()
			.withDescription(  "send this command to mote.\nCMD_START_TX = 100\nCMD_STOP_TX = 101" )
			.create( "cmd" );

		// automatically generate the help statement
		HelpFormatter formatter = new HelpFormatter();

		options.addOption(comm);
		options.addOption(cmd);
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
			Stats serial = new Stats(mif);

			if(line.hasOption("cmd")) {
				String x = line.getOptionValue("cmd");
				System.out.println(x);
			}

		}
		catch( ParseException exp ) {
			// oops, something went wrong
			System.err.println( "Parsing failed.  Reason: " + exp.getMessage() );
		}
	}
}

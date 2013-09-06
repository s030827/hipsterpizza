# encoding: utf-8

def warning(message)
  %(<p class="text-warning">#{message}</p>#{home_button})
end

def error(message)
  %(<p class="text-error">#{message}</p>#{home_button})
end

def show_saved_orders_button
  %( <a class="btn btn-info" href="#{$current_host}/?action=showsaved">Show Saved Orders</a>)
end

def new_order_button
  %( <a class="btn btn-success" href="#{$current_host}/?action=neworder&amp;knddomain=1" data-no-turbolink>Make New Order</a>)
end

def home_button
  %( <a class="btn" href="#{$current_host}">Go Home/Reload</a>)
end

def html_header
  %(<!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>HipsterPizza Overview</title>
        <link rel="stylesheet" href="bootstrap.min.css" type="text/css" />
        <script src="turbolinks.js"></script>
        <script src="gui-nick-handler.js"></script>
      </head>
      <body>
        <div class="masthead">
          <h3><img src="images/logo.png" width="200" height="86">HipsterPizza</h3>
        </div>
        <noscript><div class="large text-error" style="padding:10px">pizza.de and #{$current_host} need JavaScript. Disable your snake oil please.</div></noscript>)
end

def html_footer
  %(<br/><br/></body></html>)
end

def overview_table
  return "" unless table_exists?
  out = "<h2>Overview</h2>"
  out << %(<table class="table table-striped"><tr><th>Nick</th><th class="price">€</th><th>Paid?</th><th>Order</th><th>Actions</th></tr>)
  $db.execute("SELECT * FROM #{table_name} ORDER BY nick COLLATE NOCASE ASC") do |row|
    order = JSON.parse(row["querystring"])
    sum = order["items"].map { |i| i["price"].to_f }.inject(0, :+)
    paid = row["paid"] == 1
    qry = "id=#{row["id"]}&amp;date=#{Date.today.strftime("%Y-%m-%d")}"
    out << "<tr>"
    out << "<td>#{order["nick"]}</td>"
    out << %(<td class="price">#{'%.2f' % sum}</td>)
    out << %(<td title="click to toggle">)
    if paid
      out << %(<a class="btn btn-success" href="?action=togglepaid&amp;#{qry}">iPaid</a>)
    else
      out << %(<a class="btn btn-warning" href="?action=togglepaid&amp;#{qry}">NOPE</a>)
    end
    out << %(</td>)
    out << "<td>#{render_order_details(order)}</td>"
    out << %(<td style="white-space: nowrap;">)

    out << %( <a title="Save Order As" class="btn" onclick="var name=prompt('Choose a unique name for saving:', hipsterGetNick() + ': '); name=name.replace(/^\\s+|\\s+$/, ''); if(name == null || name == '') return false; else window.location.search='?action=saveorder&amp;#{qry}&amp;name='+name;">Save</a> )

    unless order_submitted?
      out << %( <a title="Copy Order" class="btn" onclick="if(confirm('Copy this order?\\n\\n• Basically the same as “Make New Order” but faster.\\n• Will hang your browser for a while.\\n• No failsafes.\\n• You can change the order before submitting it to HipsterPizza.')) window.location.search='?action=copy&amp;#{qry}&amp;knddomain=1'; return false;">cp</a>)
      out << %( <a data-nick="#{order["nick"]}" title="Edit Order" class="btn onlyWithCookies" onclick="if(confirm('Edit “#{order["nick"]}”s order?\\n\\n• Will hang your browser for a while.\\n• No failsafes.\\n• Order remains unchanged until you hit “Bestellen”.')) window.location.search='?action=edit&amp;#{qry}&amp;knddomain=1'; return false;">Edit</a>)
      out << %( <a data-nick="#{order["nick"]}" title="Delete Order" class="btn btn-danger onlyWithCookies" onclick="if(confirm('Do you really want to remove “#{order["nick"]}”s order?')) window.location.search='?action=delete&amp;#{qry}'; return false;">❌</a> )
    end
    out << "</td>"
    out << "</tr>"
  end
  out << "</table>"

  out << <<-EOF
    <script>
      window.autoUpdate = function() {
        // we navigated to a subpage, don’t reload
        if(location.search !== "") return;

        var x = document.querySelectorAll(":hover");
        for(var i = 0; i < x.length; i++) {
          if(x[i].tagName !== "A") continue;
          // okay, so mouse is over a link. Reload later.
          window.setTimeout(window.autoUpdate, "10000");
          return;
        }
        Turbolinks.visit("#{$current_host}#refresh=" + new Date().toLocaleTimeString());
      }
      if(window.autoUpdateTimeout) window.clearTimeout(window.autoUpdateTimeout);
      window.autoUpdateTimeout = window.setTimeout(window.autoUpdate, "10000");
    </script>
  EOF

  out
end

def saved_orders_table
  return "<h2>No saved orders</h2>" unless table_exists?("saved")
  out = "<h2>Saved Orders</h2>"
  out << %(<table class="table table-striped"><tr><th>Name</th><th>Order</th><th>Actions</th></tr>)
  $db.execute("SELECT * FROM saved ORDER BY name COLLATE NOCASE ASC") do |row|
    order = JSON.parse(row["querystring"])
    qry = "name=#{row["name"]}&amp;date=#{Date.today.strftime("%Y-%m-%d")}"
    out << "<tr>"
    out << "<td>#{row["name"]}</td>"
    out << "<td>#{render_order_details(order)}</td>"
    out << %(<td style="white-space: nowrap;">)

    if (ONLY_ON.nil? || Time.now.send(ONLY_ON+"?")) && !order_submitted?
      out << %( <a title="Order EXACTLY this" class="btn" style="font-weight: bold" onclick="window.location.search='?action=ordersaved&amp;submitImmediately=yes&amp;#{qry}&amp;knddomain=1'; return false;">Order. This. NOW!</a>)
      out << %( <a title="Create new order based on this one" class="btn" onclick="if(confirm('Really order this?\\n\\n• Will hang your browser for a while.\\n• No failsafes.\\n• You can change the order before commiting it to HipsterPizza.')) window.location.search='?action=ordersaved&amp;#{qry}&amp;knddomain=1'; return false;">order &amp; customize</a>)
    end

    out << %( <a title="Delete Saved Order" class="btn btn-danger" onclick="if(confirm('Really delete saved order?')) window.location.search='?action=deletesaved&amp;#{qry}'; return false;">❌</a> )
    out << "</td>"
    out << "</tr>"
  end
  out << "</table>"
  out
end

def render_order_details(order)
  out = "<ul>"
  a = order["items"].map do |item|
    ingred = item["extra"] * " + "
    ingred = ingred.empty? ? "" : " + #{ingred}"
    "<li>#{item["prod"]}#{ingred}</li>"
  end
  out << a.join
  out << "</ul>"
end

def user_actions
  out = "<h2>What can I do?</h2>"
  out << home_button
  if order_submitted?
    out << %( <span class="btn disabled">Wait. Don’t bitch.</span>)
  elsif ONLY_ON.nil? || Time.now.send(ONLY_ON+"?")
    out << new_order_button
  else
    # note that this is not enforced.
    out << %( <span class="btn disabled">Can only order on #{ONLY_ON}s.</span>)
    #out << new_order_button # debugging
  end
  out << show_saved_orders_button
  out << %(<br><br>)
end


def money_stats
  return "" unless table_exists?

  onpile = 0
  offpile = 0

  $db.execute("SELECT * FROM #{table_name}") do |row|
    order = JSON.parse(row["querystring"])
    sum = order["items"].map { |i| i["price"] }.inject(0, :+)
    if row["paid"] == 1
      onpile += sum
    else
      offpile += sum
    end
  end

  out = "<h2>Summary</h2>"
  out << %(<strong class="lead large">)
  out << %(<span class="muted">∑ = #{'%.2f' % (onpile + offpile)}€)
  out << %(&nbsp;&nbsp;&nbsp;&nbsp;pile = #{'%.2f' % onpile}€</span>)
  out << %(&nbsp;&nbsp;&nbsp;&nbsp;2go = #{'%.2f' % offpile}€)
  out << %(</strong><br/><br/>)
end

def order_status
  out = ""
  out << %(<h2>Order Status</h2>)
  if order_submitted?
    t = order_submit_date
    out << %(<p class="lead">submitted @ #{t.getlocal.strftime("%H:%M")} (#{t.time_ago_in_words})</p>)

    if deli = order_delivery_date
      out << %(<p class="lead">delivered @ #{deli.getlocal.strftime("%H:%M")} (#{deli.time_ago_in_words})</p>)
    else
      sum = get_sum_for_order || 0
      avg = avg_delivery_time
      if avg > 0
        est = t + (avg * sum)
        out << %(<p class="lead">estimate @ #{est.getlocal.strftime("%H:%M")} (#{est.time_ago_in_words})</p>)
      end
    end

    out << %(<a class="btn" onclick="if(confirm('Are you sure the delivery has arrived NOW? Otherwise click cancel and don’t insert a time to avoid skewing the stats.')) window.location.search='?action=markdelivered'; return false;" title="only click if “a wild pizza appears”">delivery arrived?</a>)
  else
    out << %(<p class="lead">The order has not yet been submitted.</p>)
    out << %(This means you can still order. It will be submitted around 8 PM. <strong>If it’s almost 8 PM and you still want to order SHOUT VERY LOUD or CALL SOMEONE AT LOCATION.</strong>)
    out << %(<div style="height:1000px"></div><div class="fakehidden"><p>)
    out << %(<a class="btn btn-warning" onclick="if(confirm('Click OK if you want to:\\n• Pay for everyone\\n• Block further orders\\n• rape your browser and init group order.\\n\\nOtherwise kindly leave the premesis.')) window.location.search='?action=submit&amp;knddomain=1'; return false;">I will pay for everyone</a> Don’t click, this button will brew incredibly awesome Latte no hipster can withstand.<br/><br/>)
    out << %(<a class="btn" href="?action=genpdf" download="hipsterpizza-order.pdf">Generate PDF</a> No evil things will happen if you click this. I promise!<br/><br/>)
    out << %(<a class="btn" onclick="a = document.querySelectorAll('.onlyWithCookies'); for(var i = 0; i < a.length; i++) { a[i].setAttribute('class', a[i].getAttribute('class').replace('onlyWithCookies','' )); }">SuperPowers Activate</a> Gives SuperAIDS. Don’t trust the button.)
    out << %(</p></div>)
  end
  out
end

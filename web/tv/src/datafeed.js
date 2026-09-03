import {
	makeApiRequest,
	generateSymbol,
	// parseFullSymbol,
	// getAllSymbols,
	dayChart,
	getchart,
	getSymbol,
	getIndicators
} from './helpers.js';
import {
	subscribeOnStream,
	unsubscribeFromStream,
	// getResolution,
	socketfirst
} from './streaming.js';
var queryString = window.location.search;
var urlParams = new URLSearchParams(queryString);
var product = urlParams.get('symbol')

var subscribeid;

const lastBarsCache = new Map();
// var data;
// var data11;
// var data2;
// var data22;
// var volume = 0;
// var ddata;
// var cdata;
// var vdata;
// let bars = [];
// var symbolItem;
// var searchdata;
// var searchSymbols;
// var searchdata = "RELIANCE::NSE";
// var symbolName = {token:"2885"};
var queryString = window.location.search;
var urlParams = new URLSearchParams(queryString);
var usession = urlParams.get('usession')
var user = urlParams.get('user')
// var exc = urlParams.get('exc')
// console.log("TOKENNNNNNNNNNNNNNNNNNN",tokenfurl)
// var token = tokenfurl;
// var convertedtoken;
const configurationData = {

	supported_resolutions: ['1', '3', '5', '15', '30', '45', '60', '120', '180', '240', '1D', '1W', '1M'],
};
let reqno = 0

let getSymbols = ""

// console.log("Version: ",TradingView.version());

export default {
	onReady: (callback) => {
		// console.log('[onReady]: Method call');
		setTimeout(() => callback(configurationData));
	},

	resolveSymbol: async (
		symbolName,
		onSymbolResolvedCallback,
		onResolveErrorCallback,
	) => {
		getSymbols = await getSymbol(symbolName.includes(":") ? symbolName.split(":")[1] : symbolName);
		// console.log('[resolveSymbol]: Method call', symbolName, getSymbols);
		const symbols = await makeApiRequest(`https://go.mynt.in/NorenWClientWeb/GetSecurityInfo`, getSymbols);
		if (symbols && symbols.stat == "Ok") {
			console.log("symbol info", `:|=|:${symbols.exch}|${symbols.token}`)
		}
		// https://api.zebull.in/rest/V2MobullService/chart/symbols?symbol=BANKNIFTY29SEP22FUT%3A%3ANFO"
		// var sy = [];
		// bars = [];
		// // console.log(symbols,symbols.ticker);
		// var json = JSON.parse(symbols);
		// if(json.ticker != undefined){
		// token = json.ticker;
		// }
		// console.log("TOKEN INSIDE:",json, token);
		// sy = [JSON.parse(symbols)];
		// console.log("SSVSHJSDS: ", sy)
		// if(sy[0]['exchange-traded'] == 'NSE' || sy[0]['exchange-traded'] == 'BSE'){
		// 	symbolItem = sy.find(({
		// 		name,
		// 	}) => name === symbolName);
		// }
		// else if(sy[0]['exchange-traded'] == 'NFO'){
		// 	symbolItem = sy.find(({
		// 		description,
		// 	}) => description === symbolName.slice(0, -5));
		// }
		// console.log("symbolName",symbols);
		// if (!symbolItem) {
		// 	// console.log('[resolveSymbol]: Cannot resolve symbol', symbolName);
		// 	onResolveErrorCallback('cannot resolve symbol');
		// 	return;
		// }
		var symbolInfo = {};
		symbolInfo = {
			ticker: symbols.tsym,
			name: symbols.tsym,
			description: symbols.tsym,
			// type: symbolItem.type,
			symbols_types: [{ name: "All types", value: "" }],
			value: symbols["exch"],
			session: symbols["exch"] == "MCX" ? "0900-2355:23456" : (symbols["exch"] == "CDS" || symbols["exch"] == "BCD") ? "0900-1700:23456" : '0915-1540:23456',
			timezone: 'Asia/Kolkata',
			exchange: symbols["exch"],
			minmov: 1,
			pricescale: 100,
			has_intraday: true,
			has_weekly_and_monthly: false,
			has_daily: true,
			intraday_multipliers: ["1"],
			daily_multipliers: ["1"],
			weekly_multipliers: ["1"],
			monthly_multipliers: ["1"],
			has_no_volume: false,
			// visible_plots_set: true,
			has_weekly_and_monthly: false,
			supported_resolutions: configurationData.supported_resolutions,
			volume_precision: 1,
			data_status: 'streaming',
			// preset: "mobile",
			charts_storage_url: "https://chartbe.mynt.in",
			charts_storage_api_version: "1.1",
			client_id: "Mynt_mob",
			user_id: user,
		};
		// window.tvWidget.activeChart().resetData();
		// console.log("symbol: ", symbolInfo);
		// console.log('[resolveSymbol]: Symbol resolved', symbolInfo);
		onSymbolResolvedCallback(symbolInfo);
	},

	// searchSymbols: async (
	// 	userInput,
	// 	exchange,
	// 	symbolType,
	// 	onResultReadyCallback
	// ) => {
	// 	// console.log('[searchSymbols]: Method call');
	// 	const symbols = await getAllSymbols(userInput);
	// 	console.log("Symbols from Search: ", symbols);
	// 	searchSymbols = symbols.filter(symbol => symbol)
	// 		.map(value => {
	// 			console.log(value.exchange_segment);
	// 			if(value.exchange_segment == "bse_cm" || value.exchange_segment == "nse_cm"){
	// 				var group = "stock";
	// 				var stock = value.symbol.slice(0, -3) + "::" + value.exch;
	// 			}
	// 			else{
	// 				var group = "index";
	// 				var stock = value.instrument_name + "::" + value.exch
	// 			}
	// 			return {
	// 				exchanges: [{ name:"All Exchanges",value: ""},{name:value.exch,value:value.exch}],
	// 				symbols_types: [{ name:"All Types",value: ""},{name:"stock", value:"stock"},{name:"index",value:"index"}],
	// 				symbol: value.symbol + ":" + value.exch,
	// 				// symbolType: group,
	// 				full_name: value.instrument_name,
	// 				description: value.instrument_name,
	// 				exchange: value.exch,
	// 				ticker: stock,
	// 				type: group,
	// 			};
	// 		});

	// 	// if (searchSymbols.exchange == 'BSE') {
	// 	// 	console.log(searchSymbols.exchange);
	// 	// 	searchdata = searchSymbols.symbol + "::" + searchSymbols.exchange;
	// 	// }
	// 	// else if (searchSymbols.exchange == 'NSE') {
	// 	// 	console.log(searchSymbols.exchange);
	// 	// 	searchdata = (searchSymbols.symbol).slice(0, -3) + "::" + searchSymbols.exchange;
	// 	// }
	// 	// console.log("searchSymbols: ", searchSymbols)
	// 	onResultReadyCallback(searchSymbols);

	// 	// window.tvWidget.setSymbol(searchdata,"1",() => null);
	// },

	subscribeBars: (
		symbolInfo,
		resolution,
		onRealtimeCallback,
		subscribeUID,
		onResetCacheNeededCallback,
	) => {
		// subscribeid = subscribeUID;
		// console.log('[subscribeBars]: Method call with subscribeUID:', subscribeUID);
		subscribeOnStream(
			symbolInfo,
			resolution,
			onRealtimeCallback,
			subscribeUID,
			onResetCacheNeededCallback,
			lastBarsCache.get(product),
		);
	},

	unsubscribeBars: (subscriberUID) => {
		// console.log('[unsubscribeBars]: Method call with subscriberUID:', subscriberUID);
		unsubscribeFromStream(subscriberUID);
	},


	getBars: async (symbolInfo, resolution, periodParams, onHistoryCallback, onErrorCallback) => {
		// console.log("symbolget", symbolInfo,resolution)
		// let oisymbol=false
		// console.log("DID YOU IO resolution :",symbolInfo,resolution,periodParams)
		// if(symbolInfo.name.includes("$OISYMBOL")){
		//     oisymbol=true
		// }
		let requestOptions
		var data11
		// let consym = "";
		// if(resolution=="1D" || resolution=="1W" || resolution=="1M"){
		// if(symbolInfo.isTradable != true){
		//     let symnamearr = symbolInfo.base_name.split(" ")
		//     for (let i in symnamearr){
		//         let firstletter = symnamearr[i].charAt(0) + symnamearr[i].substring(1).toLowerCase()
		//         consym += firstletter + " "
		//     }
		//     consym = symbolInfo['exchange']+":"+consym.substring(0, consym.length-1)
		// }
		// requestOptions = `jData={"uid":"${userid}","exch":"${symbolInfo['exchange']}","token":"${symbolInfo['base_name']}","st":"${periodParams.from - 320000}","et":"${periodParams.to}","intrv":"${resolution}"}&jKey=${usession}`;
		// requestOptions = JSON.stringify({"sym":consym,"from":periodParams.from,"to":periodParams.to})
		// let symName;
		// // console.log("sym , " ,symbolInfo.type)
		// if(symbolInfo.type == 'index'){
		//     symName = symbolInfo.exchange+":"+symbolInfo.base_name
		// }
		// else{
		//     symName = symbolInfo.name;
		// }
		// symName = symName.includes("$OISYMBOL")?symName.replace("$OISYMBOL",""):symName;
		// symName = symName.includes(" ")?symName.replace(" ","%20"):symName;
		// symName = symName.includes("&")?symName.replace("&","%26"):symName;
		// requestOptions = JSON.stringify({"sym":symName,"from":periodParams.from,"to":periodParams.to})
		// data11 = await makeApiRequest(`https://go.mynt.in/chartApi/getdata`, requestOptions);
		// if(data11.length>0){
		//      data11 = await data11.map(JSON.parse);
		//     // data11=JSON.parse(data11)
		//     // console.log("data11 : ",data11)
		// }else{
		//     // console.log("data11 :::::::: ",data11!=[])
		//     onHistoryCallback([], { noData: true });
		//     return;
		// }

		// }else{
		if (resolution == "1D" || resolution == "1W" || resolution == "1M") {
			let symName = symbolInfo.name;
			symName = symName.includes("$OISYMBOL") ? symName.replace("$OISYMBOL", "") : symName;
			symName = symName.includes(" ") ? symName.replace(" ", "%20") : symName;
			symName = symName.includes("&") ? symName.replace("&", "%26") : symName;
			requestOptions = JSON.stringify({ "sym": getSymbols['index'], "from": periodParams.from, "to": periodParams.to })
			data11 = await dayChart(`https://go.mynt.in/chartApi/getdata`, requestOptions);
			if (data11.length > 0) {
				data11 = await data11.map(JSON.parse);
				// data11=JSON.parse(data11)
				// console.log("data11 : ",data11)
			} else {
				// console.log("data11 :::::::: ",data11!=[])
				onHistoryCallback([], { noData: true });
				return;
			}
		}
		else {
			// console.log("symb", symbolInfo)
			let symName;
			symName = symbolInfo['base_name'].includes("$OISYMBOL") ? symbolInfo['base_name'].replace("$OISYMBOL", "") : symbolInfo['base_name'];
			symName = symName.includes("&") ? symName.replace("&", "%26") : symName;
			requestOptions = `jData={"uid":"${user}","exch":"${getSymbols['exch']}","token":"${getSymbols['Token']}","st":"${periodParams.from - 320000}","et":"${periodParams.to}","intrv":"${resolution}"}&jKey=${usession}`;
			data11 = await getchart(`https://go.mynt.in/NorenWClientWeb/TPSeries`, requestOptions);
		}

		// }
		try {
			if (data11.stat == 'Not_Ok' || data11 == []) {
				console.log("No Data ")
				onHistoryCallback([], {noData: true });
				return;
			}
			let data = data11.map(d => {
				return { time: parseFloat(d.ssboe), open: parseFloat(d.into), high: parseFloat(d.inth), low: parseFloat(d.intl), close: parseFloat(d.intc), volume: parseFloat(d.intv), oi: parseFloat(d.oi) }
			});
			data = data.sort((a, b) => parseFloat(a.time) - parseFloat(b.time));
			// console.log("[bar] data : ",data)
			var bars = [];
			// if(oisymbol){
			//     data.forEach(bar => {
			//         bars = [...bars, {
			//             time: bar.time * 1000,
			//             low: bar.low,
			//             high: bar.high,
			//             open: bar.open,
			//             volume: bar.volume,
			//             close: bar.oi,
			//             oi:bar.oi
			//         }];
			//     });
			//     // console.log("bars :: ",bars)
			// }
			// else{
			data.forEach(bar => {
				bars = [...bars, {
					time: bar.time * 1000,
					low: bar.low,
					high: bar.high,
					open: bar.open,
					volume: bar.volume,
					close: bar.close,
					oi: bar.oi
				}];
			});
			// }


			// console.log("[bar] data : ",bars)
			if (periodParams.firstDataRequest) {
				lastBarsCache.set(product, {
					...bars[bars.length - 1],
				});
			}
			// console.log("lst bar cache", lastBarsCache)
			// await getcprData(symbolInfo,periodParams);
			onHistoryCallback(bars, { noData: false });
			// window.tvWidget.activeChart().executeActionById("chartReset");

			document.getElementById('spinnerDisplay').style.display = 'none';
			document.getElementById('tv_chart_container').style.display = 'block';
			socketfirst();


		} catch (error) {
			// console.log('[getBars]: Get error', error);
			onErrorCallback(error);
		}
	},


};

export function getsubscribeuid() {
	return subscribeid
}
// export function	getVolume(){
// 	console.log("Data Feed :", data2);
// 	vdata = data2.map(d => {
// 		volume += d.Volume;
// 		console.log('Data Volume: ',volume, typeof(volume));
// 		return volume
// 	});
// 	volume = 0;
// 	console.log("Data Feed Volume: ",vdata)
// 	return vdata;
// };
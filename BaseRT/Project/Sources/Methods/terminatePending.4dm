//%attributes = {"invisible":true,"preemptive":"capable"}
#DECLARE($signal : 4D.Signal)

var $worker : cs.workers.worker
$worker:=cs.workers.worker.new(cs._server)
$worker.terminate()
cs._startup.new().endStop()
$signal.trigger()
